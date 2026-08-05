import type { ProviderFailure } from "./failures.ts";
import type { LifecyclePhase } from "./lifecycle.ts";
import type { PreventiveExecutionAttestation } from "./preventive-execution-containment.ts";

export interface CertificateConfiguration {
  readonly nodeExtraCaCerts?: string;
  readonly sslCertFile?: string;
}

export interface RuntimeValidationRequest {
  readonly executableName?: string;
  readonly path?: string;
  readonly initializationTimeoutMs?: number;
  readonly shutdownTimeoutMs?: number;
  readonly restart?: boolean;
  readonly certificateConfiguration?: CertificateConfiguration;
}

/** Deliberately credential-free authentication validation request. */
export interface AuthenticationValidationRequest extends RuntimeValidationRequest {
  readonly interactive?: boolean;
  readonly authenticationTimeoutMs?: number;
  /** Explicit opt-in to a manifest-pinned recovery flow; never exposes its code/URL. */
  readonly deviceCodeRecovery?: boolean;
}

/** Credential-free, read-only allowance validation. This is not a job dispatch API. */
export interface AllowanceValidationRequest extends RuntimeValidationRequest {
  readonly allowanceTimeoutMs?: number;
}

/** A live request is intentionally impossible to satisfy until Story 1.6 proves containment. */
export interface StructuredOutputValidationRequest extends RuntimeValidationRequest {
  readonly live?: boolean;
  readonly jobId: string;
  /** Opaque, one-use proof minted only by the preventive containment gate. */
  readonly containmentAttestation?: PreventiveExecutionAttestation;
}

export interface PreventiveExecutionContainmentRequest extends RuntimeValidationRequest {
  readonly jobId: string;
  /** This does not enable a live provider probe; it is an explicit future opt-in. */
  readonly live?: boolean;
}

/**
 * Cleanup is deliberately a narrow, provider-neutral capability.  It is not a
 * thread, turn, or generic RPC dispatch surface: callers may only enumerate
 * records that were marked as ProjectOS-managed by their own durable outbox
 * and may only request deletion in the same authentication context.
 */
export interface ManagedProviderSession {
  /** Opaque outbox correlation, used only to recover an interrupted fake create. */
  readonly cleanupObligationId: string;
  readonly opaqueSessionId: string;
  readonly authenticationContextFingerprint: string;
  readonly providerProfileId: string;
  readonly managedSource: "projectos_cleanup_outbox_v1";
}

export interface ProviderSessionCleanupRequest {
  readonly providerProfileId: string;
  readonly authenticationContextFingerprint: string;
  readonly managedSource: "projectos_cleanup_outbox_v1";
}

export interface ProviderSessionDeleteRequest extends ProviderSessionCleanupRequest {
  readonly opaqueSessionId: string;
}

export type ProviderSessionCleanupFailureCode =
  | "adapter_unavailable"
  | "reauth_required"
  | "delete_pending";

export type ProviderSessionListResult =
  | Readonly<{ readonly ok: true; readonly complete: true; readonly sessions: readonly ManagedProviderSession[] }>
  | Readonly<{ readonly ok: false; readonly code: ProviderSessionCleanupFailureCode }>;

export type ProviderSessionDeleteResult =
  | Readonly<{ readonly ok: true; readonly outcome: "deleted" | "absent" }>
  | Readonly<{ readonly ok: false; readonly code: ProviderSessionCleanupFailureCode }>;

/** Validation-only cleanup surface.  It intentionally has no create, turn, or job method. */
export interface ProviderSessionCleanupPort {
  listManagedSessions(request: ProviderSessionCleanupRequest): Promise<ProviderSessionListResult>;
  deleteManagedSession(request: ProviderSessionDeleteRequest): Promise<ProviderSessionDeleteResult>;
}

export interface PreventiveExecutionContainmentSuccess {
  readonly ok: true;
  readonly correlationId: string;
  readonly attemptId: string;
  readonly containmentAttestation: PreventiveExecutionAttestation;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}

export interface PreventiveExecutionContainmentRejection {
  readonly ok: false;
  readonly code: "containment_boundary_unavailable" | "containment_rejected" | "evidence_write_failed";
  readonly correlationId: string;
  readonly stopCondition: string;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}
export type PreventiveExecutionContainmentResult =
  | PreventiveExecutionContainmentSuccess
  | PreventiveExecutionContainmentRejection;

export interface StructuredOutputValidationRejection {
  readonly ok: false;
  readonly code: "containment_attestation_required" | "structured_output_rejected" | "evidence_write_failed";
  readonly correlationId: string;
  readonly stopCondition: string;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}

export interface AllowanceValidationSuccess {
  readonly ok: true;
  readonly correlationId: string;
  readonly runtimeVersion: string;
  readonly providerReadiness: "available" | "temporarily_unavailable";
  readonly localProjectOSCapability: "available";
  readonly buckets: readonly import("./allowance.ts").AllowanceBucket[];
  readonly remedy: import("./allowance.ts").AllowanceRemedy | null;
  readonly shutdownOutcome: ShutdownOutcome;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}

export type AllowanceValidationResult = AllowanceValidationSuccess | ProviderFailure;

export type AuthenticationState =
  | "signed_out"
  | "authenticated_chatgpt"
  | "cancelled"
  | "expired"
  | "failed"
  | "secure_storage_unavailable"
  | "unsupported";

export interface AuthenticationValidationSuccess {
  readonly ok: true;
  readonly correlationId: string;
  readonly authenticationState: AuthenticationState;
  readonly planCategory: "pro" | "other" | "unknown";
  readonly expectedPro: "matched" | "not_matched" | "unknown";
  readonly deviceCodeCapability: "supported" | "unsupported";
  readonly logoutOutcome: "completed" | "not_needed";
  readonly profileIsolation: "unchanged";
  readonly credentialOwnership: "codex_keyring_only";
  readonly retryable: boolean;
  readonly shutdownOutcome: ShutdownOutcome;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}

export type AuthenticationValidationResult = AuthenticationValidationSuccess | ProviderFailure;

export type ShutdownOutcome =
  | "not_started"
  | "clean_exit"
  | "graceful_termination"
  | "forced_termination"
  | "unexpected_exit"
  | "shutdown_failure";

export interface RuntimeHealthSuccess {
  readonly ok: true;
  readonly correlationId: string;
  readonly lifecycle: readonly LifecyclePhase[];
  readonly runtimeVersion: string;
  readonly compatibilityStatus: "compatible";
  readonly attemptId: string;
  readonly attemptCount: 1 | 2;
  readonly manifestId: string;
  readonly schemaDigests: {
    readonly jsonSha256: string;
    readonly typescriptSha256: string;
  };
  readonly shutdownOutcome: ShutdownOutcome;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}

export type RuntimeHealthResult = RuntimeHealthSuccess | ProviderFailure;

export interface AiProviderPort {
  validateRuntime(request: RuntimeValidationRequest): Promise<RuntimeHealthResult>;
  validateAuthentication?(
    request: AuthenticationValidationRequest,
  ): Promise<AuthenticationValidationResult>;
  validateAllowance?(
    request: AllowanceValidationRequest,
  ): Promise<AllowanceValidationResult>;
  validateStructuredOutput?(
    request: StructuredOutputValidationRequest,
  ): Promise<StructuredOutputValidationRejection>;
  validatePreventiveExecutionContainment?(
    request: PreventiveExecutionContainmentRequest,
  ): Promise<PreventiveExecutionContainmentResult>;
}
