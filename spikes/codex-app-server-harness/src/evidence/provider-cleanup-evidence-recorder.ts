import { randomUUID } from "node:crypto";
import { constants } from "node:fs";
import { chmod, lstat, mkdir, open, realpath, rename, rm } from "node:fs/promises";
import { join } from "node:path";
import type { ProviderCleanupEvidence } from "./provider-cleanup-evidence-schema.ts";

const FORBIDDEN = /token|secret|authorization|api[_-]?key|account|https?:\/\/|\/(?:Users|tmp|private|var)\/|prompt|payload|raw|content|canonical|binding|context_preview|credential|authentication|identity|session|adapter|provider_profile|path/iu;
const COUNT_KEYS = ["absent", "confirmed", "created", "ledgerGaps", "pending", "reauthRequired", "rolloutMetadata"];
const CHECKS = ["crash_reconciliation", "intent_before_create", "local_erasure_separate", "managed_metadata_removed", "sanitized_aggregate"];
const STOPS = ["containment_boundary_unavailable", "live_codex_cleanup_unproven"];

export function sanitizeProviderCleanupEvidence(value: ProviderCleanupEvidence): ProviderCleanupEvidence {
  const counts = value.counts as Record<string, unknown>; const numeric = (key: string): number => counts[key] as number;
  if (value.schemaVersion !== 1 || !safeId(value.runId) || !safeId(value.correlationId) || value.decision !== "reject" || value.reproductionCommand !== "npm run validate:provider-cleanup" || Object.keys(counts).sort().join(",") !== COUNT_KEYS.join(",") || !Object.values(counts).every((count) => typeof count === "number" && Number.isSafeInteger(count) && count >= 0) || numeric("created") !== numeric("confirmed") + numeric("absent") + numeric("pending") + numeric("reauthRequired") + numeric("ledgerGaps") || numeric("ledgerGaps") !== 0 || numeric("rolloutMetadata") > numeric("pending") + numeric("reauthRequired") || !validSet(value.checks, CHECKS) || !validSet(value.stopConditions, STOPS) || value.stopConditions.length !== 2 || FORBIDDEN.test(JSON.stringify(value))) throw new Error("evidence_write_failed");
  return Object.freeze({ ...value, counts: Object.freeze({ ...value.counts }), checks: Object.freeze([...value.checks]), stopConditions: Object.freeze([...value.stopConditions]) });
}

export async function writeProviderCleanupEvidence(value: ProviderCleanupEvidence, root: string): Promise<string> {
  let staging: string | undefined;
  try {
    const sanitized = sanitizeProviderCleanupEvidence(value); const base = await privateRoot(root);
    staging = join(base, `.${sanitized.runId}-${randomUUID()}.tmp`); await mkdir(staging, { mode: 0o700 }); await chmod(staging, 0o700);
    const destination = join(staging, "provider-cleanup-summary.json"); const file = await open(destination, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY, 0o600);
    try { await file.writeFile(`${JSON.stringify(sanitized, null, 2)}\n`); await file.sync(); } finally { await file.close(); }
    await chmod(destination, 0o600); const final = join(base, `${sanitized.runId}-provider-cleanup`); await rename(staging, final); return join(final, "provider-cleanup-summary.json");
  } catch { if (staging) await rm(staging, { recursive: true, force: true }).catch(() => {}); throw new Error("evidence_write_failed"); }
}

function safeId(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/u.test(value) && !FORBIDDEN.test(value); }
function validSet(values: readonly string[], allowed: readonly string[]): boolean { return Array.isArray(values) && values.length === new Set(values).size && values.length === allowed.length && values.every((value) => allowed.includes(value)); }
async function privateRoot(root: string): Promise<string> { try { const metadata = await lstat(root); if (!metadata.isDirectory() || metadata.isSymbolicLink() || (metadata.mode & 0o077) !== 0) throw new Error("unsafe_root"); } catch (error: unknown) { if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error; await mkdir(root, { recursive: true, mode: 0o700 }); await chmod(root, 0o700); } return realpath(root); }
