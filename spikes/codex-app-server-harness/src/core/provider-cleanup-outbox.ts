import { constants } from "node:fs";
import { chmod, lstat, mkdir, open, readFile, realpath, rename, rm } from "node:fs/promises";
import { basename, join } from "node:path";

export const PROVIDER_CLEANUP_OUTBOX_VERSION = 1 as const;
export const MANAGED_SESSION_SOURCE = "projectos_cleanup_outbox_v1" as const;

export type ProviderCleanupLifecycle =
  | "create_intent"
  | "bound"
  | "retired"
  | "delete_pending"
  | "reauth_required"
  | "confirmed"
  | "absent";

export interface ProviderCleanupReceipt {
  readonly outcome: "confirmed" | "absent";
  readonly completedAt: string;
}

/**
 * This is intentionally the whole durable record.  In particular it has no
 * Project, Conversation, binding, preview, content, account, credential, or
 * provider-metadata field.  The opaque session ID is populated only after the
 * external create effect is known.
 */
export interface ProviderCleanupObligation {
  readonly id: string;
  readonly adapterId: string;
  readonly providerProfileId: string;
  readonly authenticationContextFingerprint: string;
  readonly opaqueSessionId: string | null;
  readonly lifecycle: ProviderCleanupLifecycle;
  readonly retryCount: number;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly receipt: ProviderCleanupReceipt | null;
}

interface ProviderCleanupOutboxDocument {
  readonly schemaVersion: 1;
  readonly obligations: readonly ProviderCleanupObligation[];
}

export interface CreateCleanupIntent {
  readonly id: string;
  readonly adapterId: string;
  readonly providerProfileId: string;
  readonly authenticationContextFingerprint: string;
}

export interface ProviderCleanupOutboxOptions {
  readonly now?: () => string;
}

/** A private, atomically-published durability boundary for cleanup continuity. */
export class ProviderCleanupOutbox {
  readonly #root: string;
  readonly #file: string;
  readonly #now: () => string;
  #obligations: ProviderCleanupObligation[];

  private constructor(root: string, obligations: readonly ProviderCleanupObligation[], options: ProviderCleanupOutboxOptions) {
    this.#root = root;
    this.#file = join(root, "provider-cleanup-outbox.json");
    this.#obligations = [...obligations];
    this.#now = options.now ?? (() => new Date().toISOString());
  }

  static async open(root: string, options: ProviderCleanupOutboxOptions = {}): Promise<ProviderCleanupOutbox> {
    const privateRoot = await ensurePrivateRoot(root);
    const file = join(privateRoot, "provider-cleanup-outbox.json");
    let obligations: readonly ProviderCleanupObligation[] = [];
    try {
      const metadata = await lstat(file);
      if (!metadata.isFile() || metadata.isSymbolicLink() || (metadata.mode & 0o077) !== 0) throw new Error("cleanup_outbox_invalid");
      obligations = parseDocument(JSON.parse(await readFile(file, "utf8"))).obligations;
    } catch (error: unknown) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw new Error("cleanup_outbox_invalid");
    }
    return new ProviderCleanupOutbox(privateRoot, obligations, options);
  }

  list(): readonly ProviderCleanupObligation[] { return Object.freeze(this.#obligations.map(freezeObligation)); }
  get(id: string): ProviderCleanupObligation | null { return this.#obligations.find((entry) => entry.id === id) ?? null; }

  /** Must complete before any simulated or real external session-create effect. */
  async recordCreateIntent(input: CreateCleanupIntent): Promise<ProviderCleanupObligation> {
    if (!validIntent(input) || this.get(input.id) !== null) throw new Error("cleanup_outbox_invalid");
    const now = this.#timestamp();
    return this.#append({ ...input, opaqueSessionId: null, lifecycle: "create_intent", retryCount: 0, createdAt: now, updatedAt: now, receipt: null });
  }

  async bindCreatedSession(id: string, opaqueSessionId: string): Promise<ProviderCleanupObligation> {
    return this.#transition(id, ["create_intent"], (entry, now) => ({ ...entry, opaqueSessionId, lifecycle: "bound", updatedAt: now }));
  }

  /** Discovery after an interrupted create retains a prior local-erasure fact. */
  async bindDiscoveredSession(id: string, opaqueSessionId: string): Promise<ProviderCleanupObligation> {
    return this.#transition(id, ["create_intent", "retired"], (entry, now) => ({ ...entry, opaqueSessionId, lifecycle: entry.lifecycle === "retired" ? "retired" : "bound", updatedAt: now }));
  }

  /** Called only after local content and ordinary bindings are irreversibly erased. */
  async recordLocalDeletion(id: string): Promise<ProviderCleanupObligation> {
    return this.#transition(id, ["create_intent", "bound", "delete_pending", "reauth_required", "retired"], (entry, now) => ({ ...entry, lifecycle: "retired", updatedAt: now }));
  }

  async recordDeletePending(id: string): Promise<ProviderCleanupObligation> {
    return this.#transition(id, ["bound", "retired", "delete_pending", "reauth_required"], (entry, now) => ({ ...entry, lifecycle: "delete_pending", retryCount: entry.retryCount + 1, updatedAt: now }));
  }

  async recordReauthenticationRequired(id: string): Promise<ProviderCleanupObligation> {
    return this.#transition(id, ["bound", "retired", "delete_pending", "reauth_required"], (entry, now) => ({ ...entry, lifecycle: "reauth_required", retryCount: entry.retryCount + 1, updatedAt: now }));
  }

  async recordTerminal(id: string, outcome: "confirmed" | "absent"): Promise<ProviderCleanupObligation> {
    return this.#transition(id, ["bound", "retired", "delete_pending", "reauth_required"], (entry, now) => {
      if (entry.opaqueSessionId === null) throw new Error("cleanup_outbox_transition_invalid");
      return { ...entry, lifecycle: outcome, updatedAt: now, receipt: { outcome, completedAt: now } };
    });
  }

  #timestamp(): string { const timestamp = this.#now(); if (!isTimestamp(timestamp)) throw new Error("cleanup_outbox_invalid"); return timestamp; }
  async #append(entry: ProviderCleanupObligation): Promise<ProviderCleanupObligation> { await this.#replace([...this.#obligations, entry]); return this.get(entry.id)!; }
  async #transition(id: string, allowed: readonly ProviderCleanupLifecycle[], reducer: (entry: ProviderCleanupObligation, now: string) => ProviderCleanupObligation): Promise<ProviderCleanupObligation> {
    const index = this.#obligations.findIndex((entry) => entry.id === id);
    if (index < 0) throw new Error("cleanup_outbox_invalid");
    const current = this.#obligations[index]!;
    if (current.lifecycle === "confirmed" || current.lifecycle === "absent") return freezeObligation(current);
    if (!allowed.includes(current.lifecycle)) throw new Error("cleanup_outbox_transition_invalid");
    const proposed = this.#timestamp();
    const next = reducer(current, proposed < current.updatedAt ? current.updatedAt : proposed);
    if (!isObligation(next) || next.id !== current.id || next.createdAt !== current.createdAt) throw new Error("cleanup_outbox_invalid");
    const all = [...this.#obligations]; all[index] = next; await this.#replace(all); return this.get(id)!;
  }
  async #replace(entries: readonly ProviderCleanupObligation[]): Promise<void> {
    // Reload-and-merge prevents a second live handle from dropping another
    // process's independently published create intent. Same-ID conflicts fail closed.
    const current = await readExisting(this.#file);
    const proposed = new Map(entries.map((entry) => [entry.id, entry]));
    for (const existing of current) {
      const replacement = proposed.get(existing.id);
      if (!replacement) proposed.set(existing.id, existing);
      else if (replacement.updatedAt < existing.updatedAt) throw new Error("cleanup_outbox_conflict");
    }
    const document = freezeDocument({ schemaVersion: PROVIDER_CLEANUP_OUTBOX_VERSION, obligations: [...proposed.values()] });
    const temporary = join(this.#root, `.${basename(this.#file)}-${process.pid}-${Math.random().toString(16).slice(2)}.tmp`);
    try {
      const handle = await open(temporary, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY, 0o600);
      try { await handle.writeFile(`${JSON.stringify(document)}\n`); await handle.sync(); } finally { await handle.close(); }
      await chmod(temporary, 0o600); await rename(temporary, this.#file);
      const directory = await open(this.#root, "r"); try { await directory.sync(); } finally { await directory.close(); }
      this.#obligations = document.obligations.map(freezeObligation);
    } catch (error) { await rm(temporary, { force: true }).catch(() => {}); throw error; }
  }
}

async function readExisting(file: string): Promise<readonly ProviderCleanupObligation[]> { try { return parseDocument(JSON.parse(await readFile(file, "utf8"))).obligations; } catch (error: unknown) { if (error instanceof Error && "code" in error && error.code === "ENOENT") return []; throw error; } }

function parseDocument(value: unknown): ProviderCleanupOutboxDocument { if (!record(value) || !exactKeys(value, ["obligations", "schemaVersion"]) || value.schemaVersion !== 1 || !Array.isArray(value.obligations) || !value.obligations.every(isObligation) || new Set(value.obligations.map((entry) => entry.id)).size !== value.obligations.length || new Set(value.obligations.flatMap((entry) => entry.opaqueSessionId === null ? [] : [entry.opaqueSessionId])).size !== value.obligations.filter((entry) => entry.opaqueSessionId !== null).length) throw new Error("cleanup_outbox_invalid"); return freezeDocument({ schemaVersion: 1, obligations: value.obligations }); }
function freezeDocument(document: ProviderCleanupOutboxDocument): ProviderCleanupOutboxDocument { return Object.freeze({ schemaVersion: 1, obligations: Object.freeze(document.obligations.map(freezeObligation)) }); }
function freezeObligation(value: ProviderCleanupObligation): ProviderCleanupObligation { return Object.freeze({ ...value, receipt: value.receipt === null ? null : Object.freeze({ ...value.receipt }) }); }
function validIntent(value: CreateCleanupIntent): boolean { return record(value) && exactKeys(value, ["adapterId", "authenticationContextFingerprint", "id", "providerProfileId"]) && isId(value.id) && isAdapterId(value.adapterId) && isId(value.providerProfileId) && isFingerprint(value.authenticationContextFingerprint); }
function isObligation(value: unknown): value is ProviderCleanupObligation { if (!record(value) || !exactKeys(value, ["adapterId", "authenticationContextFingerprint", "createdAt", "id", "lifecycle", "opaqueSessionId", "providerProfileId", "receipt", "retryCount", "updatedAt"]) || !isId(value.id) || !isAdapterId(value.adapterId) || !isId(value.providerProfileId) || !isFingerprint(value.authenticationContextFingerprint) || !(value.opaqueSessionId === null || isOpaqueSessionId(value.opaqueSessionId)) || !isLifecycle(value.lifecycle) || !nonNegative(value.retryCount) || !isTimestamp(value.createdAt) || !isTimestamp(value.updatedAt) || value.updatedAt < value.createdAt) return false; if ((value.lifecycle === "confirmed" || value.lifecycle === "absent") !== (value.receipt !== null)) return false; return value.receipt === null || record(value.receipt) && exactKeys(value.receipt, ["completedAt", "outcome"]) && value.receipt.outcome === value.lifecycle && isTimestamp(value.receipt.completedAt) && value.receipt.completedAt >= value.createdAt; }
function isLifecycle(value: unknown): value is ProviderCleanupLifecycle { return value === "create_intent" || value === "bound" || value === "retired" || value === "delete_pending" || value === "reauth_required" || value === "confirmed" || value === "absent"; }
function record(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function exactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean { const keys = Object.keys(value).sort(); return keys.length === expected.length && keys.every((key, index) => key === expected[index]); }
function isId(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z][A-Za-z0-9._-]{0,127}$/u.test(value); }
function isAdapterId(value: unknown): value is string { return typeof value === "string" && /^[a-z][a-z0-9-]{0,63}$/u.test(value); }
function isFingerprint(value: unknown): value is string { return typeof value === "string" && /^sha256:[a-f0-9]{64}$/u.test(value); }
function isOpaqueSessionId(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$/u.test(value); }
function nonNegative(value: unknown): value is number { return typeof value === "number" && Number.isSafeInteger(value) && value >= 0; }
function isTimestamp(value: unknown): value is string { if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u.test(value)) return false; const date = new Date(value); return !Number.isNaN(date.valueOf()) && date.toISOString() === value; }
async function ensurePrivateRoot(root: string): Promise<string> { try { const metadata = await lstat(root); if (!metadata.isDirectory() || metadata.isSymbolicLink() || (metadata.mode & 0o077) !== 0) throw new Error("cleanup_outbox_invalid"); } catch (error: unknown) { if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error; await mkdir(root, { recursive: true, mode: 0o700 }); await chmod(root, 0o700); } return realpath(root); }
