import type { AllowanceBucket, AllowanceRemedy } from "../core/allowance.ts";
import type { ProviderFailureCode } from "../core/failures.ts";

/** Versioned safe diagnostic: no provider payload, event name, identity, URL, or path. */
export interface AllowanceValidationEvidence {
  readonly schemaVersion: 1;
  readonly runId: string;
  readonly correlationId: string;
  readonly result: "proceed" | "reject";
  readonly runtimeVersion: string | null;
  readonly providerReadiness: "available" | "temporarily_unavailable";
  readonly buckets: readonly AllowanceBucket[];
  readonly remedy: AllowanceRemedy | null;
  readonly failureCode: ProviderFailureCode | null;
  readonly reproductionCommand: "PROJECTOS_LIVE_ALLOWANCE=1 npm run test:allowance:live";
}
