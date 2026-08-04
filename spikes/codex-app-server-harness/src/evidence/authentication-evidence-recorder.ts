import { constants } from "node:fs";
import { chmod, lstat, mkdir, open, realpath, rename, rm } from "node:fs/promises";
import { join } from "node:path";
import { randomUUID } from "node:crypto";

import type { AuthenticationValidationEvidence } from "./authentication-evidence-schema.ts";
import { sanitizeAuthenticationEvidence } from "./authentication-evidence-sanitizer.ts";

export async function writeAuthenticationEvidence(
  evidence: AuthenticationValidationEvidence,
  root: string,
): Promise<string> {
  let staging: string | undefined;
  try {
    const safe = sanitizeAuthenticationEvidence(evidence);
    if (!safeRunId(evidence.runId)) throw new Error("invalid_run_id");
    const evidenceRoot = await preparePrivateEvidenceRoot(root);
    const directory = join(evidenceRoot, `${evidence.runId}-authentication`);
    staging = join(evidenceRoot, `.${evidence.runId}-${randomUUID()}.tmp`);
    await mkdir(staging, { mode: 0o700 }); await chmod(staging, 0o700);
    const path = join(staging, "authentication-summary.json");
    const handle = await open(path, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY, 0o600);
    try { await handle.writeFile(`${JSON.stringify(safe, null, 2)}\n`, "utf8"); await handle.sync(); }
    finally { await handle.close(); }
    await chmod(path, 0o600); await rename(staging, directory); return join(directory, "authentication-summary.json");
  } catch {
    if (staging) await rm(staging, { recursive: true, force: true }).catch(() => {});
    throw new Error("evidence_write_failed");
  }
}

async function preparePrivateEvidenceRoot(root: string): Promise<string> {
  try {
    const metadata = await lstat(root);
    if (metadata.isSymbolicLink() || !metadata.isDirectory() || (metadata.mode & 0o077) !== 0) {
      throw new Error("unsafe_evidence_root");
    }
  } catch (error: unknown) {
    if (!isMissing(error)) throw error;
    await mkdir(root, { recursive: true, mode: 0o700 });
    await chmod(root, 0o700);
  }
  const metadata = await lstat(root);
  if (metadata.isSymbolicLink() || !metadata.isDirectory() || (metadata.mode & 0o077) !== 0) {
    throw new Error("unsafe_evidence_root");
  }
  return realpath(root);
}

function safeRunId(value: string): boolean {
  return /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/u.test(value);
}

function isMissing(error: unknown): boolean {
  return error instanceof Error && "code" in error && error.code === "ENOENT";
}
