import { randomUUID } from "node:crypto";

export const FAILURE_CODES = [
  "runtime_not_found",
  "runtime_not_executable",
  "version_probe_failed",
  "runtime_snapshot_failed",
  "unsupported_runtime_build",
  "protocol_binary_mismatch",
  "schema_generation_failed",
  "invalid_protocol_manifest",
  "protocol_schema_mismatch",
  "missing_required_method",
  "unsupported_dispatch",
  "protocol_compatibility_required",
  "runtime_terminated_during_checking",
  "restart_failed",
  "spawn_failed",
  "initialization_rejected",
  "malformed_handshake_response",
  "initialization_timeout",
  "unexpected_exit_or_eof",
  "shutdown_timeout",
  "shutdown_failed",
  "isolation_failed",
  "evidence_write_failed",
] as const;

export type ProviderFailureCode = (typeof FAILURE_CODES)[number];

export interface RemediationMetadata {
  readonly action:
    | "install_runtime"
    | "repair_runtime"
    | "retry_validation"
    | "inspect_local_evidence"
    | "check_permissions";
  readonly reference?: string;
}

export interface ProviderFailure {
  readonly ok: false;
  readonly code: ProviderFailureCode;
  readonly correlationId: string;
  readonly remediation: RemediationMetadata;
  readonly compatibilityStatus?: "incompatible";
  readonly detectedBuild?: string;
  readonly supportedBuild?: string;
  readonly diagnosticReference?: string;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}

export function createCorrelationId(): string {
  return `projectos-${randomUUID()}`;
}

export function createProviderFailure(input: {
  readonly code: ProviderFailureCode;
  readonly correlationId?: string;
  readonly remediation: RemediationMetadata;
  readonly compatibilityStatus?: "incompatible";
  readonly detectedBuild?: string;
  readonly supportedBuild?: string;
  readonly diagnosticReference?: string;
}): ProviderFailure {
  return Object.freeze({
    ok: false,
    code: input.code,
    correlationId: input.correlationId ?? createCorrelationId(),
    remediation: Object.freeze({ ...input.remediation }),
    ...(input.compatibilityStatus ? { compatibilityStatus: input.compatibilityStatus } : {}),
    ...(input.detectedBuild ? { detectedBuild: input.detectedBuild } : {}),
    ...(input.supportedBuild ? { supportedBuild: input.supportedBuild } : {}),
    ...(input.diagnosticReference ? { diagnosticReference: input.diagnosticReference } : {}),
    providerActionEnabled: false,
    canonicalStateOperationEnabled: false,
  });
}
