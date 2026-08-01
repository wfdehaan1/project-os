import { randomUUID } from "node:crypto";
import { chmod, lstat, mkdir, rename, rm, writeFile } from "node:fs/promises";

import type { ProviderFailureCode } from "../core/failures.ts";
import type { PrivateRunEvidence } from "./evidence-schema.ts";
import { sanitizeRunEvidence } from "./sanitizer.ts";

export class EvidenceWriteError extends Error {
  readonly code: ProviderFailureCode = "evidence_write_failed";

  constructor() {
    super("evidence_write_failed");
    this.name = "EvidenceWriteError";
  }
}

export interface EvidencePaths {
  readonly runDirectory: string;
  readonly privateEvidencePath: string;
  readonly sanitizedSummaryPath: string;
}

export async function writeRunEvidence(
  evidence: PrivateRunEvidence,
  evidenceRoot: string,
): Promise<EvidencePaths> {
  let stagingDirectory: string | undefined;
  try {
    validateEvidence(evidence);
    await prepareEvidenceRoot(evidenceRoot);
    if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/u.test(evidence.runId)) throw new Error();
    const runDirectory = `${evidenceRoot}/${evidence.runId}`;
    stagingDirectory = `${evidenceRoot}/.${evidence.runId}.${randomUUID()}.tmp`;
    await mkdir(stagingDirectory, { mode: 0o700 });
    await chmod(stagingDirectory, 0o700);
    const privateEvidencePath = `${stagingDirectory}/private.json`;
    const sanitizedSummaryPath = `${stagingDirectory}/summary.json`;
    await atomicPrivateJson(privateEvidencePath, evidence);
    await atomicPrivateJson(sanitizedSummaryPath, sanitizeRunEvidence(evidence));
    await rename(stagingDirectory, runDirectory);
    return {
      runDirectory,
      privateEvidencePath: `${runDirectory}/private.json`,
      sanitizedSummaryPath: `${runDirectory}/summary.json`,
    };
  } catch (error: unknown) {
    if (stagingDirectory) await rm(stagingDirectory, { recursive: true, force: true }).catch(() => {});
    if (error instanceof EvidenceWriteError) throw error;
    throw new EvidenceWriteError();
  }
}

function validateEvidence(evidence: PrivateRunEvidence): void {
  if (
    evidence.schemaVersion !== 1 ||
    !evidence.runId ||
    !evidence.correlationId ||
    !evidence.startedAt ||
    !evidence.completedAt ||
    evidence.lifecycle.length === 0 ||
    !evidence.reproductionCommand
  ) {
    throw new EvidenceWriteError();
  }
  if (evidence.result === "failed" && !evidence.failureCode) throw new EvidenceWriteError();
  if (evidence.result === "passed" && evidence.failureCode) throw new EvidenceWriteError();
  if (
    evidence.result === "passed" &&
    (!evidence.runtimeVersion ||
      !evidence.candidateExecutablePath ||
      !evidence.resolvedExecutablePath ||
      !evidence.runtimePaths ||
      !evidence.strictConfigurationFingerprint ||
      evidence.handshakeOutcome !== "initialized" ||
      evidence.isolationComparison !== "unchanged" ||
      evidence.lifecycle.at(-1) !== "stopped" ||
      !["clean_exit", "graceful_termination", "forced_termination"].includes(
        evidence.shutdownOutcome,
      ))
  ) {
    throw new EvidenceWriteError();
  }
}

async function prepareEvidenceRoot(path: string): Promise<void> {
  try {
    const metadata = await lstat(path);
    if (metadata.isSymbolicLink() || !metadata.isDirectory()) throw new EvidenceWriteError();
  } catch (error: unknown) {
    if (!isMissing(error)) throw error;
    await mkdir(path, { recursive: true, mode: 0o700 });
  }
  await chmod(path, 0o700);
}

async function atomicPrivateJson(path: string, value: unknown): Promise<void> {
  const temporaryPath = `${path}.${randomUUID()}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(value, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
    flag: "wx",
  });
  await chmod(temporaryPath, 0o600);
  await rename(temporaryPath, path);
  await chmod(path, 0o600);
}

function isMissing(error: unknown): boolean {
  return error instanceof Error && "code" in error && error.code === "ENOENT";
}
