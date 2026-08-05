import { randomUUID } from "node:crypto";
import { chmod, lstat, mkdir, open, readFile, realpath, rename, rm } from "node:fs/promises";
import { join } from "node:path";
import type { ManagedProviderSession, ProviderSessionCleanupFailureCode, ProviderSessionCleanupPort } from "./ai-provider-port.ts";
import { MANAGED_SESSION_SOURCE, ProviderCleanupOutbox, type ProviderCleanupObligation } from "./provider-cleanup-outbox.ts";

export interface CleanupContext {
  readonly adapterId: string;
  readonly providerProfileId: string;
  readonly authenticationContextFingerprint: string;
}

/** An injected fake-only create effect; the public provider port remains cleanup-only. */
interface ManagedSessionCreateEffect {
  createManagedSession(input: { readonly cleanupObligationId: string; readonly providerProfileId: string; readonly authenticationContextFingerprint: string }): Promise<{ readonly opaqueSessionId: string }>;
}

export class ProviderSessionCleanupCoordinator {
  readonly #outbox: ProviderCleanupOutbox;
  readonly #provider: ProviderSessionCleanupPort;
  readonly #context: CleanupContext;

  constructor(input: { readonly outbox: ProviderCleanupOutbox; readonly provider: ProviderSessionCleanupPort; readonly context: CleanupContext }) {
    if (!validContext(input.context)) throw new Error("cleanup_context_invalid");
    this.#outbox = input.outbox; this.#provider = input.provider; this.#context = input.context;
  }

  /** Persist-first simulated creation.  A throw after the effect leaves create_intent durable. */
  async createWithDurableIntent(input: { readonly id: string; readonly createEffect: ManagedSessionCreateEffect }): Promise<ProviderCleanupObligation> {
    await this.#outbox.recordCreateIntent({ id: input.id, ...this.#context });
    const created = await input.createEffect.createManagedSession({ cleanupObligationId: input.id, providerProfileId: this.#context.providerProfileId, authenticationContextFingerprint: this.#context.authenticationContextFingerprint });
    return this.#outbox.bindCreatedSession(input.id, created.opaqueSessionId);
  }

  /** Local erasure is a separate, durable fact and never calls a provider. */
  async recordLocalProjectDeletion(input: { readonly obligationId: string; readonly eraseLocalProject: () => Promise<void> }): Promise<ProviderCleanupObligation> {
    await input.eraseLocalProject();
    return this.#outbox.recordLocalDeletion(input.obligationId);
  }

  /**
   * Reconciliation is ledger-conserving and repeatable.  It never sends local
   * content: list/delete requests contain only the current profile, context
   * fingerprint, managed-source marker, and an already opaque handle.
   */
  async reconcile(): Promise<readonly ProviderCleanupObligation[]> {
    const outstanding = this.#outbox.list().filter((entry) => !terminal(entry));
    const sameAdapterAndProfile = outstanding.filter((entry) => entry.adapterId === this.#context.adapterId && entry.providerProfileId === this.#context.providerProfileId);
    for (const entry of outstanding.filter((entry) => entry.adapterId !== this.#context.adapterId || entry.providerProfileId !== this.#context.providerProfileId)) {
      if (entry.opaqueSessionId !== null) await this.#outbox.recordDeletePending(entry.id);
    }
    for (const entry of sameAdapterAndProfile.filter((item) => item.authenticationContextFingerprint !== this.#context.authenticationContextFingerprint)) {
      if (entry.opaqueSessionId !== null) await this.#outbox.recordReauthenticationRequired(entry.id);
    }
    const matching = sameAdapterAndProfile.filter((entry) => entry.authenticationContextFingerprint === this.#context.authenticationContextFingerprint);
    if (matching.length === 0) return this.#outbox.list();
    const listed = await this.#provider.listManagedSessions({ providerProfileId: this.#context.providerProfileId, authenticationContextFingerprint: this.#context.authenticationContextFingerprint, managedSource: MANAGED_SESSION_SOURCE });
    if (!listed.ok) { await Promise.all(matching.filter((entry) => entry.opaqueSessionId !== null).map((entry) => listed.code === "reauth_required" ? this.#outbox.recordReauthenticationRequired(entry.id) : this.#outbox.recordDeletePending(entry.id))); return this.#outbox.list(); }
    if (!listed.complete) { await Promise.all(matching.filter((entry) => entry.opaqueSessionId !== null).map((entry) => this.#outbox.recordDeletePending(entry.id))); return this.#outbox.list(); }
    const valid = listed.sessions.filter((session) => session.managedSource === MANAGED_SESSION_SOURCE && session.providerProfileId === this.#context.providerProfileId && session.authenticationContextFingerprint === this.#context.authenticationContextFingerprint);
    const duplicates = new Set(valid.filter((session, index) => valid.findIndex((other) => other.cleanupObligationId === session.cleanupObligationId) !== index).map((session) => session.cleanupObligationId));
    const byObligation = new Map(valid.map((session) => [session.cleanupObligationId, session]));
    for (const entry of matching) {
      let current = this.#outbox.get(entry.id)!;
      const discovered = byObligation.get(entry.id);
      if (current.opaqueSessionId === null) {
        if (!discovered) continue; // creation may have happened but is not provable; retain intent.
        if (duplicates.has(current.id)) { await this.#outbox.recordDeletePending(current.id); continue; }
        current = await this.#outbox.bindDiscoveredSession(current.id, discovered.opaqueSessionId);
      }
      if (current.opaqueSessionId === null) continue; // a pre-create crash remains explicitly pending.
      if (current.lifecycle !== "retired" && current.lifecycle !== "delete_pending" && current.lifecycle !== "reauth_required") continue;
      if (!discovered) { await this.#outbox.recordTerminal(current.id, "absent"); continue; }
      if (discovered.opaqueSessionId !== current.opaqueSessionId) { await this.#outbox.recordDeletePending(current.id); continue; }
      const deleted = await this.#provider.deleteManagedSession({ providerProfileId: this.#context.providerProfileId, authenticationContextFingerprint: this.#context.authenticationContextFingerprint, managedSource: MANAGED_SESSION_SOURCE, opaqueSessionId: current.opaqueSessionId });
      if (deleted.ok) await this.#outbox.recordTerminal(current.id, deleted.outcome === "absent" ? "absent" : "confirmed");
      else if (deleted.code === "reauth_required") await this.#outbox.recordReauthenticationRequired(current.id);
      else await this.#outbox.recordDeletePending(current.id);
    }
    return this.#outbox.list();
  }
}

/** A deterministic private fake provider filesystem used only by offline validation. */
export class FakeProviderSessionFilesystem implements ProviderSessionCleanupPort, ManagedSessionCreateEffect {
  readonly #root: string;
  #nextListFailure: ProviderSessionCleanupFailureCode | null = null;
  #nextDeleteFailure: ProviderSessionCleanupFailureCode | null = null;
  #failRolloutMetadataRemoval = false;
  #loseNextDeleteResponse = false;

  private constructor(root: string) { this.#root = root; }
  static async open(root: string): Promise<FakeProviderSessionFilesystem> { return new FakeProviderSessionFilesystem(await privateRoot(root)); }
  failNextList(code: ProviderSessionCleanupFailureCode): void { this.#nextListFailure = code; }
  failNextDelete(code: ProviderSessionCleanupFailureCode): void { this.#nextDeleteFailure = code; }
  failRolloutMetadataRemoval(value = true): void { this.#failRolloutMetadataRemoval = value; }
  loseNextDeleteResponse(): void { this.#loseNextDeleteResponse = true; }

  async createManagedSession(input: { readonly cleanupObligationId: string; readonly providerProfileId: string; readonly authenticationContextFingerprint: string }): Promise<{ readonly opaqueSessionId: string }> {
    if (!isId(input.cleanupObligationId) || !isId(input.providerProfileId) || !isFingerprint(input.authenticationContextFingerprint)) throw new Error("fake_provider_invalid");
    const document = await this.#read(); const opaqueSessionId = `fake-${randomUUID()}`;
    document.sessions.push({ cleanupObligationId: input.cleanupObligationId, providerProfileId: input.providerProfileId, opaqueSessionId, authenticationContextFingerprint: input.authenticationContextFingerprint, managedSource: MANAGED_SESSION_SOURCE, rolloutMetadataPresent: true }); document.created += 1; await this.#write(document); return { opaqueSessionId };
  }
  async listManagedSessions(request: { readonly providerProfileId: string; readonly authenticationContextFingerprint: string; readonly managedSource: "projectos_cleanup_outbox_v1" }): Promise<import("./ai-provider-port.ts").ProviderSessionListResult> {
    if (!validRequest(request)) return { ok: false, code: "adapter_unavailable" };
    const failure = this.#nextListFailure; this.#nextListFailure = null; if (failure) return { ok: false, code: failure };
    const document = await this.#read(); return { ok: true, complete: true, sessions: Object.freeze(document.sessions.filter((entry) => entry.authenticationContextFingerprint === request.authenticationContextFingerprint && entry.providerProfileId === request.providerProfileId).map((entry) => Object.freeze({ cleanupObligationId: entry.cleanupObligationId, providerProfileId: entry.providerProfileId, opaqueSessionId: entry.opaqueSessionId, authenticationContextFingerprint: entry.authenticationContextFingerprint, managedSource: MANAGED_SESSION_SOURCE }))) };
  }
  async deleteManagedSession(request: { readonly providerProfileId: string; readonly authenticationContextFingerprint: string; readonly managedSource: "projectos_cleanup_outbox_v1"; readonly opaqueSessionId: string }): Promise<import("./ai-provider-port.ts").ProviderSessionDeleteResult> {
    if (!validRequest(request) || !isOpaqueSessionId(request.opaqueSessionId)) return { ok: false, code: "adapter_unavailable" };
    const failure = this.#nextDeleteFailure; this.#nextDeleteFailure = null; if (failure) return { ok: false, code: failure };
    const document = await this.#read(); const index = document.sessions.findIndex((entry) => entry.opaqueSessionId === request.opaqueSessionId && entry.authenticationContextFingerprint === request.authenticationContextFingerprint && entry.providerProfileId === request.providerProfileId);
    if (index < 0) return { ok: true, outcome: "absent" };
    if (this.#failRolloutMetadataRemoval || !document.sessions[index]!.rolloutMetadataPresent) return { ok: false, code: "delete_pending" };
    document.sessions.splice(index, 1); await this.#write(document);
    if (this.#loseNextDeleteResponse) { this.#loseNextDeleteResponse = false; return { ok: false, code: "delete_pending" }; }
    return { ok: true, outcome: "deleted" };
  }
  async audit(): Promise<Readonly<{ created: number; sessions: number; rolloutMetadata: number }>> { const document = await this.#read(); return Object.freeze({ created: document.created, sessions: document.sessions.length, rolloutMetadata: document.sessions.filter((entry) => entry.rolloutMetadataPresent).length }); }
  async #read(): Promise<FakeDocument> { try { return parseFake(JSON.parse(await readFile(join(this.#root, "fake-provider-sessions.json"), "utf8"))); } catch (error: unknown) { if (error instanceof Error && "code" in error && error.code === "ENOENT") return { schemaVersion: 1, created: 0, sessions: [] }; throw new Error("fake_provider_invalid"); } }
  async #write(document: FakeDocument): Promise<void> { const temporary = join(this.#root, `.fake-${randomUUID()}.tmp`); try { const file = await open(temporary, "wx", 0o600); try { await file.writeFile(`${JSON.stringify(parseFake(document))}\n`); await file.sync(); } finally { await file.close(); } await chmod(temporary, 0o600); await rename(temporary, join(this.#root, "fake-provider-sessions.json")); } catch (error) { await rm(temporary, { force: true }).catch(() => {}); throw error; } }
}

interface FakeEntry { readonly cleanupObligationId: string; readonly providerProfileId: string; readonly opaqueSessionId: string; readonly authenticationContextFingerprint: string; readonly managedSource: "projectos_cleanup_outbox_v1"; readonly rolloutMetadataPresent: boolean; }
interface FakeDocument { readonly schemaVersion: 1; created: number; sessions: FakeEntry[]; }
function parseFake(value: unknown): FakeDocument {
  if (!record(value) || !exactKeys(value, ["created", "schemaVersion", "sessions"]) || value.schemaVersion !== 1 || !Array.isArray(value.sessions)) throw new Error("fake_provider_invalid");
  const created = value.created;
  if (typeof created !== "number" || !Number.isSafeInteger(created) || created < 0 || !value.sessions.every((entry) => record(entry) && exactKeys(entry, ["authenticationContextFingerprint", "cleanupObligationId", "managedSource", "opaqueSessionId", "providerProfileId", "rolloutMetadataPresent"]) && isId(entry.cleanupObligationId) && isId(entry.providerProfileId) && isOpaqueSessionId(entry.opaqueSessionId) && isFingerprint(entry.authenticationContextFingerprint) && entry.managedSource === MANAGED_SESSION_SOURCE && typeof entry.rolloutMetadataPresent === "boolean") || new Set(value.sessions.map((entry) => entry.opaqueSessionId)).size !== value.sessions.length || created < value.sessions.length) throw new Error("fake_provider_invalid");
  return { schemaVersion: 1, created, sessions: value.sessions.map((entry) => ({ ...entry })) as FakeEntry[] };
}
function terminal(entry: ProviderCleanupObligation): boolean { return entry.lifecycle === "confirmed" || entry.lifecycle === "absent"; }
function validContext(value: CleanupContext): boolean { return isAdapterId(value.adapterId) && isId(value.providerProfileId) && isFingerprint(value.authenticationContextFingerprint); }
function validRequest(value: { readonly providerProfileId: string; readonly authenticationContextFingerprint: string; readonly managedSource: string }): boolean { return isId(value.providerProfileId) && isFingerprint(value.authenticationContextFingerprint) && value.managedSource === MANAGED_SESSION_SOURCE; }
function record(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function exactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean { const keys = Object.keys(value).sort(); return keys.length === expected.length && keys.every((key, index) => key === expected[index]); }
function isId(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z][A-Za-z0-9._-]{0,127}$/u.test(value); }
function isAdapterId(value: unknown): value is string { return typeof value === "string" && /^[a-z][a-z0-9-]{0,63}$/u.test(value); }
function isFingerprint(value: unknown): value is string { return typeof value === "string" && /^sha256:[a-f0-9]{64}$/u.test(value); }
function isOpaqueSessionId(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$/u.test(value); }
async function privateRoot(root: string): Promise<string> { try { const metadata = await lstat(root); if (!metadata.isDirectory() || metadata.isSymbolicLink() || (metadata.mode & 0o077) !== 0) throw new Error("fake_provider_invalid"); } catch (error: unknown) { if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error; await mkdir(root, { recursive: true, mode: 0o700 }); await chmod(root, 0o700); } return realpath(root); }
