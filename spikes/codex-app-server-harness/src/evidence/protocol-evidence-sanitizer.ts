import {
  PROTOCOL_EVIDENCE_SCHEMA_VERSION,
  type PrivateProtocolValidationEvidence,
  type SanitizedProtocolValidationSummary,
} from "./protocol-evidence-schema.ts";
import {
  PROTOCOL_DIGEST_ALGORITHM,
  schemaTreeAggregateBytes,
  sha256,
  type ProtocolSchemaBundle,
} from "../adapters/codex/protocol-contract.ts";
import { FAILURE_CODES, type ProviderFailureCode } from "../core/failures.ts";

const REPRODUCTION_COMMAND = "npm ci && npm run protocol:validate";
const RESTART_REPRODUCTION_COMMAND = "npm ci && npm run protocol:validate -- --restart";
const REPRODUCTION_COMMAND_SET = new Set([
  REPRODUCTION_COMMAND,
  RESTART_REPRODUCTION_COMMAND,
]);
const SHA256_PATTERN = /^[a-f0-9]{64}$/u;
const SAFE_TOKEN_PATTERN = /^[a-zA-Z0-9._:-]+$/u;
const METHOD_PATTERN = /^[a-zA-Z][a-zA-Z0-9._/-]{0,255}$/u;
const FAILURE_CODE_SET = new Set<ProviderFailureCode>(FAILURE_CODES);
const TRANSCRIPT_DIRECTIONS = new Set([
  "outbound_request",
  "outbound_notification",
  "inbound_response",
  "inbound_notification",
  "inbound_request_or_event",
]);
const REQUEST_ID_CLASSES = new Set(["initialize", "client", "unrelated", "server", "none"]);
const TRANSCRIPT_CLASSIFICATIONS = new Set([
  "sent_experimental_api_disabled",
  "sent",
  "matched",
  "unrelated",
  "semantic",
  "forbidden_side_effect",
  "unknown",
]);
const LIFECYCLE_PHASES = new Set([
  "undiscovered",
  "discovered",
  "starting",
  "initializing",
  "initialized",
  "stopping",
  "stopped",
  "failed",
]);
const SHUTDOWN_OUTCOMES = new Set([
  "not_started",
  "clean_exit",
  "graceful_termination",
  "forced_termination",
  "unexpected_exit",
  "shutdown_failure",
]);
const COMPATIBILITY_OUTCOMES = new Set(["compatible", "incompatible", "not_checked"]);

export function sanitizeProtocolEvidence(
  evidence: PrivateProtocolValidationEvidence,
): SanitizedProtocolValidationSummary {
  if (
    evidence.schemaVersion !== PROTOCOL_EVIDENCE_SCHEMA_VERSION ||
    evidence.attempts.length === 0 ||
    evidence.attempts.length > 2 ||
    !SAFE_TOKEN_PATTERN.test(evidence.runId) ||
    !SAFE_TOKEN_PATTERN.test(evidence.correlationId) ||
    !REPRODUCTION_COMMAND_SET.has(evidence.reproductionCommand) ||
    !["passed", "failed"].includes(evidence.result) ||
    (evidence.failureCode !== null && !FAILURE_CODE_SET.has(evidence.failureCode)) ||
    (evidence.result === "passed" && evidence.failureCode !== null) ||
    (evidence.result === "failed" && evidence.failureCode === null)
  ) {
    throw new Error("evidence_write_failed");
  }
  const selected = evidence.attempts.at(-1);
  if (!selected) throw new Error("evidence_write_failed");
  for (const [index, attempt] of evidence.attempts.entries()) {
    if (attempt.generation !== index + 1) throw new Error("evidence_write_failed");
    validateAttempt(attempt);
  }
  const usedRestart = evidence.attempts.length === 2 || selected.failureCode === "restart_failed";
  if (
    (usedRestart && evidence.reproductionCommand !== RESTART_REPRODUCTION_COMMAND) ||
    (evidence.attempts.length === 2 && evidence.attempts[0]?.failureCode === null) ||
    (evidence.result === "passed" &&
      (selected.failureCode !== null ||
        selected.underlyingFailureCode !== null ||
        selected.compatibilityOutcome !== "compatible" ||
        selected.detectedBuild === null ||
        selected.binaryContentSha256 === null ||
        selected.manifestId === null ||
        selected.manifestDigest === null ||
        selected.schemas === null ||
        selected.requiredMethods === null ||
        selected.enabledDispatch === null ||
        !exactValues(selected.enabledDispatch.clientRequests, ["initialize"]) ||
        !exactValues(selected.enabledDispatch.clientNotifications, ["initialized"]))) ||
    (evidence.result === "failed" &&
      (selected.failureCode === null ||
        selected.failureCode !== evidence.failureCode ||
        (evidence.attempts.length === 2 && selected.failureCode !== "restart_failed")))
  ) {
    throw new Error("evidence_write_failed");
  }
  const transcript = evidence.attempts.flatMap((attempt) => {
    const approvedMethods = approvedMethodsFor(attempt);
    let previousSequence = 0;
    return attempt.transcript.map((entry) => {
      const approvedMethod = approvedMethods.has(entry.method);
      if (
        entry.attemptId !== attempt.attemptId ||
        !Number.isSafeInteger(entry.sequence) ||
        entry.sequence <= previousSequence ||
        !TRANSCRIPT_DIRECTIONS.has(entry.direction) ||
        !REQUEST_ID_CLASSES.has(entry.requestIdClass) ||
        !TRANSCRIPT_CLASSIFICATIONS.has(entry.classification) ||
        (approvedMethod && !METHOD_PATTERN.test(entry.method))
      ) {
        throw new Error("evidence_write_failed");
      }
      previousSequence = entry.sequence;
      return Object.freeze({
        attemptId: entry.attemptId,
        sequence: entry.sequence,
        direction: entry.direction,
        method: approvedMethod ? entry.method : "$UNRECOGNIZED",
        requestIdClass: entry.requestIdClass,
        classification: entry.classification,
      });
    });
  });
  return Object.freeze({
    schemaVersion: PROTOCOL_EVIDENCE_SCHEMA_VERSION,
    runId: evidence.runId,
    correlationId: evidence.correlationId,
    result: evidence.result,
    failureCode: evidence.failureCode,
    detectedBuild: selected.detectedBuild,
    platform: selected.platform,
    architecture: selected.architecture,
    binaryContentSha256: selected.binaryContentSha256,
    manifestId: selected.manifestId,
    manifestDigest: selected.manifestDigest,
    digestAlgorithm: "projectos-schema-tree-sha256-v1",
    schemas: selected.schemas
      ? Object.freeze({
          json: sanitizeSchemaBundle(selected.schemas.json),
          typescript: sanitizeSchemaBundle(selected.schemas.typescript),
        })
      : null,
    requiredMethods: selected.requiredMethods
      ? Object.freeze({
          clientRequests: sortedUnique(selected.requiredMethods.clientRequests),
          clientNotifications: sortedUnique(selected.requiredMethods.clientNotifications),
          serverNotifications: sortedUnique(selected.requiredMethods.serverNotifications),
          serverRequests: sortedUnique(selected.requiredMethods.serverRequests),
          recognizedForbidden: sortedUnique(selected.requiredMethods.recognizedForbidden),
        })
      : null,
    enabledDispatch: selected.enabledDispatch
      ? Object.freeze({
          clientRequests: sortedUnique(selected.enabledDispatch.clientRequests),
          clientNotifications: sortedUnique(selected.enabledDispatch.clientNotifications),
        })
      : null,
    compatibilityOutcome: selected.compatibilityOutcome,
    attempts: Object.freeze(evidence.attempts.map((attempt) => Object.freeze({
      generation: attempt.generation,
      attemptId: attempt.attemptId,
      correlationId: attempt.correlationId,
      failureCode: attempt.failureCode,
      underlyingFailureCode: attempt.underlyingFailureCode,
      scope: attempt.scope,
      compatibilityOutcome: attempt.compatibilityOutcome,
      lifecycle: Object.freeze([...attempt.lifecycle]),
      shutdownOutcome: attempt.shutdownOutcome,
      diagnosticReference: attempt.diagnosticReference,
    }))),
    transcript: Object.freeze(transcript),
    logicalArgv: Object.freeze({
      json: Object.freeze(["$CODEX", "app-server", "generate-json-schema", "--out", "$JSON_OUT"] as const),
      typescript: Object.freeze(["$CODEX", "app-server", "generate-ts", "--out", "$TS_OUT"] as const),
    }),
    reproductionCommand: evidence.reproductionCommand,
  });
}

function validateAttempt(
  attempt: PrivateProtocolValidationEvidence["attempts"][number],
): void {
  if (
    !SAFE_TOKEN_PATTERN.test(attempt.attemptId) ||
    !SAFE_TOKEN_PATTERN.test(attempt.correlationId) ||
    !COMPATIBILITY_OUTCOMES.has(attempt.compatibilityOutcome) ||
    attempt.lifecycle.length === 0 ||
    attempt.lifecycle.some((phase) => !LIFECYCLE_PHASES.has(phase)) ||
    !SHUTDOWN_OUTCOMES.has(attempt.shutdownOutcome) ||
    !SAFE_TOKEN_PATTERN.test(attempt.platform) ||
    !SAFE_TOKEN_PATTERN.test(attempt.architecture) ||
    (attempt.detectedBuild !== null && !/^codex(?:-cli)?\s+[a-zA-Z0-9._+-]+$/u.test(attempt.detectedBuild)) ||
    (attempt.binaryContentSha256 !== null && !SHA256_PATTERN.test(attempt.binaryContentSha256)) ||
    (attempt.manifestDigest !== null && !SHA256_PATTERN.test(attempt.manifestDigest)) ||
    (attempt.manifestId !== null && !SAFE_TOKEN_PATTERN.test(attempt.manifestId)) ||
    (attempt.diagnosticReference !== null && !SAFE_TOKEN_PATTERN.test(attempt.diagnosticReference)) ||
    (attempt.failureCode !== null && !FAILURE_CODE_SET.has(attempt.failureCode)) ||
    (attempt.underlyingFailureCode !== null && !FAILURE_CODE_SET.has(attempt.underlyingFailureCode)) ||
    (attempt.failureCode === "restart_failed" && attempt.underlyingFailureCode === null) ||
    (attempt.failureCode !== "restart_failed" && attempt.underlyingFailureCode !== null) ||
    (attempt.scope !== null &&
      (attempt.scope !== "concurrent_instance" ||
        (attempt.failureCode !== "isolation_failed" &&
          attempt.underlyingFailureCode !== "isolation_failed")))
  ) {
    throw new Error("evidence_write_failed");
  }
}

function approvedMethodsFor(
  attempt: PrivateProtocolValidationEvidence["attempts"][number],
): Set<string> {
  return new Set([
    ...(attempt.requiredMethods?.clientRequests ?? []),
    ...(attempt.requiredMethods?.clientNotifications ?? []),
    ...(attempt.requiredMethods?.serverNotifications ?? []),
    ...(attempt.requiredMethods?.serverRequests ?? []),
    ...(attempt.requiredMethods?.recognizedForbidden ?? []),
  ]);
}

function sanitizeSchemaBundle(bundle: ProtocolSchemaBundle): ProtocolSchemaBundle {
  if (
    bundle.algorithm !== PROTOCOL_DIGEST_ALGORITHM ||
    !SHA256_PATTERN.test(bundle.aggregateSha256) ||
    bundle.files.length === 0
  ) {
    throw new Error("evidence_write_failed");
  }
  const files = [...bundle.files]
    .map((file) => {
      if (!isSafeRelativePath(file.path) || !SHA256_PATTERN.test(file.sha256)) {
        throw new Error("evidence_write_failed");
      }
      return Object.freeze({ path: file.path, sha256: file.sha256 });
    })
    .sort((left, right) => left.path < right.path ? -1 : left.path > right.path ? 1 : 0);
  if (new Set(files.map((file) => file.path)).size !== files.length) {
    throw new Error("evidence_write_failed");
  }
  if (sha256(schemaTreeAggregateBytes(files)) !== bundle.aggregateSha256) {
    throw new Error("evidence_write_failed");
  }
  return Object.freeze({
    algorithm: PROTOCOL_DIGEST_ALGORITHM,
    files: Object.freeze(files),
    aggregateSha256: bundle.aggregateSha256,
  });
}

function sortedUnique(values: readonly string[]): readonly string[] {
  if (values.some((value) => !METHOD_PATTERN.test(value))) {
    throw new Error("evidence_write_failed");
  }
  return Object.freeze([...new Set(values)].sort());
}

function exactValues(actual: readonly string[], expected: readonly string[]): boolean {
  return actual.length === expected.length &&
    actual.every((value, index) => value === expected[index]);
}

function isSafeRelativePath(path: string): boolean {
  return path.length > 0 &&
    !path.startsWith("/") &&
    !path.includes("\\") &&
    !path.split("/").some((part) => part === "" || part === "." || part === "..");
}
