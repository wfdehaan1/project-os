import { createHash } from "node:crypto";
import { basename } from "node:path";

import type { PrivateRunEvidence, SanitizedRunSummary } from "./evidence-schema.ts";

export function sanitizeRunEvidence(evidence: PrivateRunEvidence): SanitizedRunSummary {
  const summary = {
    schemaVersion: evidence.schemaVersion,
    runId: evidence.runId,
    correlationId: evidence.correlationId,
    startedAt: evidence.startedAt,
    completedAt: evidence.completedAt,
    harnessVersion: evidence.harnessVersion,
    nodeVersion: evidence.nodeVersion,
    runtimeVersion: evidence.runtimeVersion,
    executableName: evidence.resolvedExecutablePath
      ? basename(evidence.resolvedExecutablePath)
      : null,
    executableFingerprint: evidence.resolvedExecutablePath
      ? createHash("sha256")
          .update(`${evidence.resolvedExecutablePath}\0${evidence.runtimeVersion ?? "unknown"}`)
          .digest("hex")
      : null,
    strictConfigurationFingerprint: evidence.strictConfigurationFingerprint,
    allowedEnvironmentNames: [...evidence.allowedEnvironmentNames],
    environmentFingerprints: { ...evidence.environmentFingerprints },
    lifecycle: [...evidence.lifecycle],
    handshakeOutcome: evidence.handshakeOutcome,
    shutdownOutcome: evidence.shutdownOutcome,
    isolationComparison: evidence.isolationComparison,
    result: evidence.result,
    ...(evidence.failureCode ? { failureCode: evidence.failureCode } : {}),
    reproductionCommand: evidence.reproductionCommand,
  } satisfies SanitizedRunSummary;
  return Object.freeze(summary);
}
