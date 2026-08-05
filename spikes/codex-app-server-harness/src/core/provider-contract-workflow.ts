import type { ProviderOperation } from "./ai-provider-port.ts";
import { ProviderRegistry, type DispatchLease } from "./provider-registry.ts";

export interface CapabilityWorkflowResult {
  readonly operation: ProviderOperation;
  readonly status: "executed" | "degraded";
  readonly degradation: string | null;
  readonly value: unknown;
}

/** ProjectOS workflow seam: it knows only named operations and declared degradation. */
export async function runCapabilityWorkflow(registry: ProviderRegistry, operation: ProviderOperation, mandatory: readonly ProviderOperation[], request: unknown): Promise<CapabilityWorkflowResult> {
  let lease: DispatchLease;
  try { lease = registry.acquireLease(operation, mandatory); }
  catch { return Object.freeze({ operation, status: "degraded", degradation: "invalid_capability_request", value: null }); }
  try { return Object.freeze({ operation, status: "executed", degradation: null, value: await registry.dispatch(lease, request) }); }
  catch (error) {
    const degradation = error instanceof Error && /^capability_/u.test(error.message) ? error.message : "capability_dispatch_blocked";
    return Object.freeze({ operation, status: "degraded", degradation, value: null });
  }
}
