import { randomUUID } from "node:crypto";

export const FAILURE_CODES = [
  "runtime_not_found",
  "runtime_not_executable",
  "version_probe_failed",
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
}): ProviderFailure {
  return Object.freeze({
    ok: false,
    code: input.code,
    correlationId: input.correlationId ?? createCorrelationId(),
    remediation: Object.freeze({ ...input.remediation }),
    providerActionEnabled: false,
    canonicalStateOperationEnabled: false,
  });
}
