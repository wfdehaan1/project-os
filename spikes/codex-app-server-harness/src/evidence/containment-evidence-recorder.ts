import { constants } from "node:fs";
import { chmod, lstat, mkdir, open, realpath, rename, rm } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { join } from "node:path";
import type { ContainmentValidationEvidence } from "./containment-evidence-schema.ts";

const FORBIDDEN = /token|secret|authorization|api[_-]?key|account|https?:\/\/|\/(?:Users|tmp|private|var)\/|prompt|payload|raw|content|result|url|path|identity/iu;
const id = (value: string): boolean => /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/u.test(value);
const digest = (value: string | null): boolean => value === null || /^[a-f0-9]{64}$/u.test(value);
const stop = (value: unknown): value is string => typeof value === "string" && /^[a-z][a-z0-9_]{0,79}$/u.test(value) && !FORBIDDEN.test(value);

export function sanitizeContainmentEvidence(value: ContainmentValidationEvidence): ContainmentValidationEvidence {
  const observationKeys = ["allowed_read", "capability_effect", "mutation", "outside_access"];
  const observation = value.observations as Record<string, unknown>;
  if (value.schemaVersion !== 1 || !id(value.runId) || !id(value.correlationId) || !["proceed", "reject"].includes(value.result) ||
      !digest(value.runtimeFingerprint) || !digest(value.manifestFingerprint) || !Number.isSafeInteger(value.allowedReadRootCount) || value.allowedReadRootCount < 0 ||
      value.writableRootCount !== 0 || value.reproductionCommand !== "npm run validate:containment" || !["stable_runtime_disable", "verified_macos_boundary", "unavailable"].includes(value.boundary) ||
      !Array.isArray(value.instructionSources) || ![0, 1].includes(value.instructionSources.length) ||
      (value.instructionSources.length === 1 && value.instructionSources[0] !== "projectos_context_preview") ||
      !Array.isArray(value.stopConditions) || value.stopConditions.length !== Object.keys(value.stopConditions).length || !value.stopConditions.every(stop) || FORBIDDEN.test(JSON.stringify(value.stopConditions)) ||
      Object.keys(observation).sort().join(",") !== observationKeys.join(",") ||
      !Object.values(observation).every((entry) => entry === "observed" || entry === "not_observed" || entry === "not_run")) {
    throw new Error("evidence_write_failed");
  }
  if (value.result === "proceed" && (
    value.boundary === "unavailable" || value.runtimeFingerprint === null ||
    value.manifestFingerprint === null || value.allowedReadRootCount < 1 ||
    value.instructionSources.length !== 1 ||
    value.instructionSources[0] !== "projectos_context_preview" ||
    value.observations.allowed_read !== "observed" ||
    value.observations.outside_access !== "not_observed" ||
    value.observations.mutation !== "not_observed" ||
    value.observations.capability_effect !== "not_observed" ||
    value.stopConditions.length !== 0
  )) throw new Error("evidence_write_failed");
  return Object.freeze({ ...value, instructionSources: Object.freeze([...value.instructionSources]) as ContainmentValidationEvidence["instructionSources"], observations: Object.freeze({ allowed_read: observation.allowed_read as "observed" | "not_observed" | "not_run", outside_access: observation.outside_access as "observed" | "not_observed" | "not_run", mutation: observation.mutation as "observed" | "not_observed" | "not_run", capability_effect: observation.capability_effect as "observed" | "not_observed" | "not_run" }), stopConditions: Object.freeze([...value.stopConditions]) });
}

export async function writeContainmentEvidence(value: ContainmentValidationEvidence, root: string): Promise<string> {
  let staging: string | undefined;
  try {
    const base = await privateRoot(root);
    staging = join(base, `.${value.runId}-${randomUUID()}.tmp`);
    await mkdir(staging, { mode: 0o700 }); await chmod(staging, 0o700);
    const destination = join(staging, "containment-summary.json");
    const handle = await open(destination, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY, 0o600);
    try { await handle.writeFile(`${JSON.stringify(sanitizeContainmentEvidence(value), null, 2)}\n`); await handle.sync(); } finally { await handle.close(); }
    await chmod(destination, 0o600);
    const final = join(base, `${value.runId}-containment`); await rename(staging, final);
    return join(final, "containment-summary.json");
  } catch { if (staging) await rm(staging, { recursive: true, force: true }).catch(() => {}); throw new Error("evidence_write_failed"); }
}
async function privateRoot(root: string): Promise<string> { try { const metadata = await lstat(root); if (!metadata.isDirectory() || metadata.isSymbolicLink() || (metadata.mode & 0o077) !== 0) throw new Error("unsafe_root"); } catch (error: unknown) { if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error; await mkdir(root, { recursive: true, mode: 0o700 }); await chmod(root, 0o700); } return realpath(root); }
