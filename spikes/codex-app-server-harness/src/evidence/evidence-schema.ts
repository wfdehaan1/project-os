import type { ShutdownOutcome } from "../core/ai-provider-port.ts";
import type { ProviderFailureCode } from "../core/failures.ts";
import type { LifecyclePhase } from "../core/lifecycle.ts";

export const EVIDENCE_SCHEMA_VERSION = 1 as const;

export interface PrivateRuntimePaths {
  readonly runtimeRoot: string;
  readonly codexHome: string;
  readonly codexSqliteHome: string;
  readonly disposableHome: string;
  readonly workingDirectory: string;
  readonly temporaryDirectory: string;
  readonly configPath: string;
}

export interface PrivateRunEvidence {
  readonly schemaVersion: typeof EVIDENCE_SCHEMA_VERSION;
  readonly runId: string;
  readonly correlationId: string;
  readonly startedAt: string;
  readonly completedAt: string;
  readonly harnessVersion: string;
  readonly nodeVersion: string;
  readonly runtimeVersion: string | null;
  readonly candidateExecutablePath: string | null;
  readonly resolvedExecutablePath: string | null;
  readonly runtimePaths: PrivateRuntimePaths | null;
  readonly strictConfigurationFingerprint: string | null;
  readonly allowedEnvironmentNames: readonly string[];
  readonly environmentFingerprints: Readonly<Record<string, string>>;
  readonly lifecycle: readonly LifecyclePhase[];
  readonly handshakeOutcome: "initialized" | "failed";
  readonly shutdownOutcome: ShutdownOutcome;
  readonly isolationComparison: "unchanged" | "changed" | "not_completed";
  readonly result: "passed" | "failed";
  readonly failureCode: ProviderFailureCode | undefined;
  readonly reproductionCommand: string;
}

export interface SanitizedRunSummary {
  readonly schemaVersion: typeof EVIDENCE_SCHEMA_VERSION;
  readonly runId: string;
  readonly correlationId: string;
  readonly startedAt: string;
  readonly completedAt: string;
  readonly harnessVersion: string;
  readonly nodeVersion: string;
  readonly runtimeVersion: string | null;
  readonly executableName: string | null;
  readonly executableFingerprint: string | null;
  readonly strictConfigurationFingerprint: string | null;
  readonly allowedEnvironmentNames: readonly string[];
  readonly environmentFingerprints: Readonly<Record<string, string>>;
  readonly lifecycle: readonly LifecyclePhase[];
  readonly handshakeOutcome: "initialized" | "failed";
  readonly shutdownOutcome: ShutdownOutcome;
  readonly isolationComparison: "unchanged" | "changed" | "not_completed";
  readonly result: "passed" | "failed";
  readonly failureCode?: ProviderFailureCode;
  readonly reproductionCommand: string;
}
