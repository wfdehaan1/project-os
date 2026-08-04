import type { ShutdownOutcome } from "../core/ai-provider-port.ts";
import type { ProviderFailureCode } from "../core/failures.ts";
import type { LifecyclePhase } from "../core/lifecycle.ts";
import type {
  ProtocolMethodSets,
  ProtocolSchemaBundle,
  SupportedRuntimeManifest,
} from "../adapters/codex/protocol-contract.ts";
import type { StructuralProtocolTranscriptEntry } from "../adapters/codex/jsonl-rpc-connection.ts";

export const PROTOCOL_EVIDENCE_SCHEMA_VERSION = 1 as const;

export interface PrivateProtocolAttemptEvidence {
  readonly generation: 1 | 2;
  readonly attemptId: string;
  readonly correlationId: string;
  readonly failureCode: ProviderFailureCode | null;
  readonly underlyingFailureCode: ProviderFailureCode | null;
  readonly scope: "concurrent_instance" | null;
  readonly compatibilityOutcome: "compatible" | "incompatible" | "not_checked";
  readonly detectedBuild: string | null;
  readonly platform: string;
  readonly architecture: string;
  readonly binaryContentSha256: string | null;
  readonly manifestId: string | null;
  readonly manifestDigest: string | null;
  readonly manifest: SupportedRuntimeManifest | null;
  readonly resolvedExecutablePath: string | null;
  readonly snapshotExecutablePath: string | null;
  readonly jsonSchemaDirectory: string | null;
  readonly typescriptSchemaDirectory: string | null;
  readonly exactJsonArgv: readonly string[] | null;
  readonly exactTypescriptArgv: readonly string[] | null;
  readonly schemas: {
    readonly json: ProtocolSchemaBundle;
    readonly typescript: ProtocolSchemaBundle;
  } | null;
  readonly requiredMethods: (ProtocolMethodSets & {
    readonly recognizedForbidden: readonly string[];
  }) | null;
  readonly detectedMethods: ProtocolMethodSets | null;
  readonly enabledDispatch: {
    readonly clientRequests: readonly string[];
    readonly clientNotifications: readonly string[];
  } | null;
  readonly lifecycle: readonly LifecyclePhase[];
  readonly shutdownOutcome: ShutdownOutcome;
  readonly preflightProcessGroupsReaped: boolean | null;
  readonly processOwnership: {
    readonly childPid: number | null;
    readonly processGroupId: number | null;
    readonly reaped: boolean;
  } | null;
  readonly diagnosticReference: string | null;
  readonly transcript: readonly StructuralProtocolTranscriptEntry[];
  readonly privateCanary?: string;
}

export interface PrivateProtocolValidationEvidence {
  readonly schemaVersion: typeof PROTOCOL_EVIDENCE_SCHEMA_VERSION;
  readonly runId: string;
  readonly correlationId: string;
  readonly result: "passed" | "failed";
  readonly failureCode: ProviderFailureCode | null;
  readonly reproductionCommand: string;
  readonly attempts: readonly PrivateProtocolAttemptEvidence[];
}

export interface SanitizedProtocolAttemptSummary {
  readonly generation: 1 | 2;
  readonly attemptId: string;
  readonly correlationId: string;
  readonly failureCode: ProviderFailureCode | null;
  readonly underlyingFailureCode: ProviderFailureCode | null;
  readonly scope: "concurrent_instance" | null;
  readonly compatibilityOutcome: "compatible" | "incompatible" | "not_checked";
  readonly lifecycle: readonly LifecyclePhase[];
  readonly shutdownOutcome: ShutdownOutcome;
  readonly diagnosticReference: string | null;
}

export interface SanitizedProtocolValidationSummary {
  readonly schemaVersion: typeof PROTOCOL_EVIDENCE_SCHEMA_VERSION;
  readonly runId: string;
  readonly correlationId: string;
  readonly result: "passed" | "failed";
  readonly failureCode: ProviderFailureCode | null;
  readonly detectedBuild: string | null;
  readonly platform: string;
  readonly architecture: string;
  readonly binaryContentSha256: string | null;
  readonly manifestId: string | null;
  readonly manifestDigest: string | null;
  readonly digestAlgorithm: "projectos-schema-tree-sha256-v1";
  readonly schemas: PrivateProtocolAttemptEvidence["schemas"];
  readonly requiredMethods: PrivateProtocolAttemptEvidence["requiredMethods"];
  readonly enabledDispatch: PrivateProtocolAttemptEvidence["enabledDispatch"];
  readonly compatibilityOutcome: PrivateProtocolAttemptEvidence["compatibilityOutcome"];
  readonly attempts: readonly SanitizedProtocolAttemptSummary[];
  readonly transcript: readonly StructuralProtocolTranscriptEntry[];
  readonly logicalArgv: {
    readonly json: readonly ["$CODEX", "app-server", "generate-json-schema", "--out", "$JSON_OUT"];
    readonly typescript: readonly ["$CODEX", "app-server", "generate-ts", "--out", "$TS_OUT"];
  };
  readonly reproductionCommand: string;
}

export interface ProtocolEvidenceAttachment {
  readonly kind: "json" | "typescript";
  readonly sourceDirectory: string;
  readonly destinationRelativePath: string;
  readonly expectedBundle: ProtocolSchemaBundle;
}

export interface ProtocolEvidencePackage {
  readonly privateEvidence: PrivateProtocolValidationEvidence;
  readonly attachments: readonly ProtocolEvidenceAttachment[];
}
