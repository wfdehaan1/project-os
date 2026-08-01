import type { ProviderFailure } from "./failures.ts";
import type { LifecyclePhase } from "./lifecycle.ts";

export interface CertificateConfiguration {
  readonly nodeExtraCaCerts?: string;
  readonly sslCertFile?: string;
}

export interface RuntimeValidationRequest {
  readonly executableName?: string;
  readonly path?: string;
  readonly initializationTimeoutMs?: number;
  readonly shutdownTimeoutMs?: number;
  readonly certificateConfiguration?: CertificateConfiguration;
}

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
  readonly shutdownOutcome: ShutdownOutcome;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}

export type RuntimeHealthResult = RuntimeHealthSuccess | ProviderFailure;

export interface AiProviderPort {
  validateRuntime(request: RuntimeValidationRequest): Promise<RuntimeHealthResult>;
}
