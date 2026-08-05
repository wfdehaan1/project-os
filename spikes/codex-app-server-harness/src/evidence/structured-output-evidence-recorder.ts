import { constants } from "node:fs";
import { chmod, lstat, mkdir, open, realpath, rename, rm } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { join } from "node:path";
import type { StructuredOutputValidationEvidence } from "./structured-output-evidence-schema.ts";
import { sanitizeStructuredOutputEvidence } from "./structured-output-evidence-sanitizer.ts";

export async function writeStructuredOutputEvidence(evidence: StructuredOutputValidationEvidence, root: string): Promise<string> {
  let staging: string | undefined;
  try {
    const base = await privateRoot(root); staging = join(base, `.${evidence.runId}-${randomUUID()}.tmp`); await mkdir(staging, { mode: 0o700 }); await chmod(staging, 0o700);
    const destination = join(staging, "structured-output-summary.json"); const file = await open(destination, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY, 0o600);
    try { await file.writeFile(`${JSON.stringify(sanitizeStructuredOutputEvidence(evidence), null, 2)}\n`); await file.sync(); } finally { await file.close(); }
    await chmod(destination, 0o600); const final = join(base, `${evidence.runId}-structured-output`); await rename(staging, final); return join(final, "structured-output-summary.json");
  } catch { if (staging) await rm(staging, { recursive: true, force: true }).catch(() => {}); throw new Error("evidence_write_failed"); }
}
async function privateRoot(root: string): Promise<string> { try { const stat = await lstat(root); if (!stat.isDirectory() || stat.isSymbolicLink() || (stat.mode & 0o077) !== 0) throw new Error("unsafe root"); } catch (error: unknown) { if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error; await mkdir(root, { recursive: true, mode: 0o700 }); await chmod(root, 0o700); } return realpath(root); }
