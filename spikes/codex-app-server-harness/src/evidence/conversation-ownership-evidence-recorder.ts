import { randomUUID } from "node:crypto";
import { constants } from "node:fs";
import { chmod, lstat, mkdir, open, realpath, rename, rm } from "node:fs/promises";
import { join } from "node:path";
import type { ConversationOwnershipEvidence } from "./conversation-ownership-evidence-schema.ts";

const FORBIDDEN = /token|secret|authorization|api[_-]?key|account|https?:\/\/|\/(?:Users|tmp|private|var)\/|prompt|payload|raw|content|session|adapter|credential|authentication|runtime|cache|diagnostic|path|identity/iu;
const id = (value: unknown): value is string => typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/u.test(value) && !FORBIDDEN.test(value);
const digest = (value: unknown): boolean => value === null || typeof value === "string" && /^[a-f0-9]{64}$/u.test(value);
const countKeys = ["acceptedHistoryEntries", "conversations", "projects", "provenances", "rationales", "relationships", "sources", "transcriptEntries"];

export function sanitizeConversationOwnershipEvidence(value: ConversationOwnershipEvidence): ConversationOwnershipEvidence {
  const counts = value.counts as Record<string, unknown>; const checks = ["binding_excluded", "fresh_binding_required", "offline_restore", "remap_complete"];
  if (value.schemaVersion !== 1 || !id(value.runId) || !id(value.correlationId) || (value.outcome !== "proceed" && value.outcome !== "reject") || !digest(value.exportDigest) || !digest(value.restoreDigest) || value.reproductionCommand !== "npm run validate:conversation-ownership" || Object.keys(counts).sort().join(",") !== countKeys.join(",") || !Object.values(counts).every((count) => Number.isSafeInteger(count) && typeof count === "number" && count >= 0) || !Array.isArray(value.checks) || value.checks.length !== new Set(value.checks).size || !value.checks.every((check) => checks.includes(check)) || !Array.isArray(value.stopConditions) || value.stopConditions.length !== new Set(value.stopConditions).size || !value.stopConditions.every((stop) => typeof stop === "string" && /^[a-z][a-z0-9_]{0,79}$/u.test(stop) && !FORBIDDEN.test(stop)) || FORBIDDEN.test(JSON.stringify(value))) throw new Error("evidence_write_failed");
  if (value.outcome === "proceed" && (value.exportDigest === null || value.restoreDigest === null || value.counts.projects !== 1 || value.checks.length !== 4 || value.stopConditions.length !== 0)) throw new Error("evidence_write_failed");
  if (value.outcome === "reject" && value.stopConditions.length === 0) throw new Error("evidence_write_failed");
  return Object.freeze({ ...value, counts: Object.freeze({ ...value.counts }), checks: Object.freeze([...value.checks]), stopConditions: Object.freeze([...value.stopConditions]) });
}

export async function writeConversationOwnershipEvidence(value: ConversationOwnershipEvidence, root: string): Promise<string> {
  let staging: string | undefined;
  try {
    const sanitized = sanitizeConversationOwnershipEvidence(value);
    const base = await privateRoot(root); staging = join(base, `.${sanitized.runId}-${randomUUID()}.tmp`); await mkdir(staging, { mode: 0o700 }); await chmod(staging, 0o700);
    const destination = join(staging, "conversation-ownership-summary.json"); const file = await open(destination, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY, 0o600);
    try { await file.writeFile(`${JSON.stringify(sanitized, null, 2)}\n`); await file.sync(); } finally { await file.close(); }
    await chmod(destination, 0o600); const final = join(base, `${sanitized.runId}-conversation-ownership`); await rename(staging, final); return join(final, "conversation-ownership-summary.json");
  } catch { if (staging) await rm(staging, { recursive: true, force: true }).catch(() => {}); throw new Error("evidence_write_failed"); }
}
async function privateRoot(root: string): Promise<string> { try { const metadata = await lstat(root); if (!metadata.isDirectory() || metadata.isSymbolicLink() || (metadata.mode & 0o077) !== 0) throw new Error("unsafe_root"); } catch (error: unknown) { if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error; await mkdir(root, { recursive: true, mode: 0o700 }); await chmod(root, 0o700); } return realpath(root); }
