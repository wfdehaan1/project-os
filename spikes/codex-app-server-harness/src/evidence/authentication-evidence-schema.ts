import type { AuthenticationState } from "../core/ai-provider-port.ts";
import type { ProviderFailureCode } from "../core/failures.ts";

/** Versioned structural record: intentionally has no account, URL, or payload fields. */
export interface AuthenticationValidationEvidence {
  readonly schemaVersion: 1;
  readonly runId: string;
  readonly correlationId: string;
  readonly result: "proceed" | "reject";
  readonly authenticationState: AuthenticationState | null;
  readonly planCategory: "pro" | "other" | "unknown";
  readonly expectedPro: "matched" | "not_matched" | "unknown";
  readonly deviceCodeCapability: "supported" | "unsupported";
  readonly logoutOutcome: "completed" | "not_needed";
  readonly profileIsolation: "unchanged" | "not_completed";
  readonly credentialOwnership: "codex_keyring_only" | "rejected";
  readonly retryable: boolean;
  readonly failureCode: ProviderFailureCode | null;
  readonly reproductionCommand: "PROJECTOS_LIVE_AUTH=1 npm run test:auth:live";
}
