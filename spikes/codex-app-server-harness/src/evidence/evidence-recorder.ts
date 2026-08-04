import { randomUUID } from "node:crypto";
import { constants } from "node:fs";
import {
  chmod,
  lstat,
  mkdir,
  open,
  readdir,
  rename,
  rm,
} from "node:fs/promises";
import { isAbsolute, join, normalize, relative, sep } from "node:path";

import { FAILURE_CODES, type ProviderFailureCode } from "../core/failures.ts";
import type { PrivateRunEvidence } from "./evidence-schema.ts";
import {
  PROTOCOL_EVIDENCE_SCHEMA_VERSION,
  type ProtocolEvidencePackage,
} from "./protocol-evidence-schema.ts";
import { sanitizeProtocolEvidence } from "./protocol-evidence-sanitizer.ts";
import { sanitizeRunEvidence } from "./sanitizer.ts";
import {
  collectProtocolSchemaBundle,
  DEFAULT_PROTOCOL_LIMITS,
} from "../adapters/codex/protocol-contract.ts";

const MAX_PROTOCOL_ATTACHMENT_BYTES = DEFAULT_PROTOCOL_LIMITS.maximumBundleBytes * 4;
const FAILURE_CODE_SET = new Set<ProviderFailureCode>(FAILURE_CODES);

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
  readonly protocolPrivateEvidencePath?: string;
  readonly protocolSummaryPath?: string;
  readonly protocolTranscriptPath?: string;
}

export async function writeRunEvidence(
  evidence: PrivateRunEvidence,
  evidenceRoot: string,
  protocol?: ProtocolEvidencePackage,
): Promise<EvidencePaths> {
  let stagingDirectory: string | undefined;
  try {
    validateEvidence(evidence);
    if (protocol) validateProtocolEvidence(evidence, protocol);
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
    if (protocol) {
      const protocolSummary = sanitizeProtocolEvidence(protocol.privateEvidence);
      await atomicPrivateJson(
        `${stagingDirectory}/protocol-private.json`,
        protocol.privateEvidence,
      );
      await atomicPrivateJson(`${stagingDirectory}/protocol-summary.json`, protocolSummary);
      await atomicPrivateJson(
        `${stagingDirectory}/protocol-transcript.json`,
        protocolSummary.transcript,
      );
      await copyProtocolAttachments(stagingDirectory, protocol);
    }
    await rename(stagingDirectory, runDirectory);
    return protocol ? {
      runDirectory,
      privateEvidencePath: `${runDirectory}/private.json`,
      sanitizedSummaryPath: `${runDirectory}/summary.json`,
      protocolPrivateEvidencePath: `${runDirectory}/protocol-private.json`,
      protocolSummaryPath: `${runDirectory}/protocol-summary.json`,
      protocolTranscriptPath: `${runDirectory}/protocol-transcript.json`,
    } : {
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

function validateProtocolEvidence(
  evidence: PrivateRunEvidence,
  protocol: ProtocolEvidencePackage,
): void {
  const value = protocol.privateEvidence;
  if (
    value.schemaVersion !== PROTOCOL_EVIDENCE_SCHEMA_VERSION ||
    value.runId !== evidence.runId ||
    value.correlationId !== evidence.correlationId ||
    value.result !== evidence.result ||
    value.attempts.length < 1 ||
    value.attempts.length > 2 ||
    !value.reproductionCommand ||
    (value.result === "passed" && value.failureCode !== null) ||
    (value.result === "failed" && value.failureCode === null) ||
    (value.failureCode ?? undefined) !== evidence.failureCode
  ) {
    throw new EvidenceWriteError();
  }
  for (const [index, attempt] of value.attempts.entries()) {
    if (
      attempt.generation !== index + 1 ||
      !attempt.attemptId ||
      !attempt.correlationId ||
      !attempt.platform ||
      !attempt.architecture ||
      attempt.lifecycle.length === 0 ||
      attempt.transcript.some((entry) => entry.attemptId !== attempt.attemptId) ||
      (attempt.failureCode !== null && !FAILURE_CODE_SET.has(attempt.failureCode)) ||
      (attempt.underlyingFailureCode !== null &&
        !FAILURE_CODE_SET.has(attempt.underlyingFailureCode)) ||
      (attempt.failureCode === "restart_failed" && attempt.underlyingFailureCode === null) ||
      (attempt.failureCode !== "restart_failed" && attempt.underlyingFailureCode !== null) ||
      (attempt.scope !== null &&
        (attempt.scope !== "concurrent_instance" ||
          (attempt.failureCode !== "isolation_failed" &&
            attempt.underlyingFailureCode !== "isolation_failed"))) ||
      (attempt.preflightProcessGroupsReaped !== null &&
        typeof attempt.preflightProcessGroupsReaped !== "boolean") ||
      !validProcessOwnership(attempt.processOwnership)
    ) {
      throw new EvidenceWriteError();
    }
  }
}

function validProcessOwnership(
  ownership: ProtocolEvidencePackage["privateEvidence"]["attempts"][number]["processOwnership"],
): boolean {
  if (ownership === null) return true;
  return (
    (ownership.childPid === null ||
      (Number.isSafeInteger(ownership.childPid) && ownership.childPid > 0)) &&
    (ownership.processGroupId === null ||
      (Number.isSafeInteger(ownership.processGroupId) && ownership.processGroupId > 0)) &&
    typeof ownership.reaped === "boolean"
  );
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
  const handle = await open(temporaryPath, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY, 0o600);
  try {
    await handle.writeFile(`${JSON.stringify(value, null, 2)}\n`, "utf8");
    await handle.sync();
  } finally {
    await handle.close();
  }
  await chmod(temporaryPath, 0o600);
  await rename(temporaryPath, path);
  await chmod(path, 0o600);
}

async function copyProtocolAttachments(
  stagingDirectory: string,
  protocol: ProtocolEvidencePackage,
): Promise<void> {
  let totalBytes = 0;
  const destinations = new Set<string>();
  for (const attachment of protocol.attachments) {
    const destination = safeAttachmentDestination(
      stagingDirectory,
      attachment.destinationRelativePath,
    );
    if (
      destinations.has(destination) ||
      [...destinations].some((existing) =>
        destination.startsWith(`${existing}${sep}`) || existing.startsWith(`${destination}${sep}`),
      )
    ) {
      throw new EvidenceWriteError();
    }
    destinations.add(destination);
    const sourceMetadata = await lstat(attachment.sourceDirectory);
    if (sourceMetadata.isSymbolicLink() || !sourceMetadata.isDirectory()) {
      throw new EvidenceWriteError();
    }
    const sourceBundle = await collectProtocolSchemaBundle(
      attachment.sourceDirectory,
      attachment.kind,
    );
    if (JSON.stringify(sourceBundle) !== JSON.stringify(attachment.expectedBundle)) {
      throw new EvidenceWriteError();
    }
    await mkdir(destination, { recursive: true, mode: 0o700 });
    await chmod(destination, 0o700);
    totalBytes = await copyDirectory(
      attachment.sourceDirectory,
      destination,
      totalBytes,
    );
    const copiedBundle = await collectProtocolSchemaBundle(destination, attachment.kind);
    if (JSON.stringify(copiedBundle) !== JSON.stringify(attachment.expectedBundle)) {
      throw new EvidenceWriteError();
    }
  }
}

async function copyDirectory(
  sourceDirectory: string,
  destinationDirectory: string,
  initialBytes: number,
): Promise<number> {
  let totalBytes = initialBytes;
  const names = (await readdir(sourceDirectory)).sort((left, right) => left.localeCompare(right));
  for (const name of names) {
    if (name === "." || name === ".." || name.includes(sep)) throw new EvidenceWriteError();
    const source = join(sourceDirectory, name);
    const destination = join(destinationDirectory, name);
    const metadata = await lstat(source);
    if (metadata.isSymbolicLink()) throw new EvidenceWriteError();
    if (metadata.isDirectory()) {
      await mkdir(destination, { mode: 0o700 });
      await chmod(destination, 0o700);
      totalBytes = await copyDirectory(source, destination, totalBytes);
      continue;
    }
    if (!metadata.isFile()) throw new EvidenceWriteError();
    totalBytes += metadata.size;
    if (totalBytes > MAX_PROTOCOL_ATTACHMENT_BYTES) throw new EvidenceWriteError();
    await copyRegularFile(source, destination, metadata.size);
  }
  return totalBytes;
}

async function copyRegularFile(source: string, destination: string, expectedSize: number): Promise<void> {
  const sourceHandle = await open(source, constants.O_RDONLY | constants.O_NOFOLLOW);
  let bytes: Buffer;
  try {
    const metadata = await sourceHandle.stat();
    if (!metadata.isFile() || metadata.size !== expectedSize) throw new EvidenceWriteError();
    bytes = await sourceHandle.readFile();
  } finally {
    await sourceHandle.close();
  }
  if (bytes.length !== expectedSize) throw new EvidenceWriteError();
  const destinationHandle = await open(
    destination,
    constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY | constants.O_NOFOLLOW,
    0o600,
  );
  try {
    await destinationHandle.writeFile(bytes);
    await destinationHandle.sync();
  } finally {
    await destinationHandle.close();
  }
  await chmod(destination, 0o600);
}

function safeAttachmentDestination(stagingDirectory: string, relativePath: string): string {
  if (
    !relativePath ||
    isAbsolute(relativePath) ||
    relativePath.includes("\\") ||
    relativePath.split("/").some((part) => part === "" || part === "." || part === "..")
  ) {
    throw new EvidenceWriteError();
  }
  const destination = join(stagingDirectory, normalize(relativePath));
  const fromStaging = relative(stagingDirectory, destination);
  if (!fromStaging || fromStaging.startsWith(`..${sep}`) || isAbsolute(fromStaging)) {
    throw new EvidenceWriteError();
  }
  return destination;
}

function isMissing(error: unknown): boolean {
  return error instanceof Error && "code" in error && error.code === "ENOENT";
}
