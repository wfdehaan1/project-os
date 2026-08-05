import type { ProviderCapabilitySnapshot, ProviderOperation, ProviderOperationAdapter } from "../../src/core/ai-provider-port.ts";

const operations = ["health", "generation", "streaming", "cancellation", "structured_result", "session_cleanup"] as const;

/** Local-shaped fake deliberately lacks auth/session/usage equivalents and configurable streaming/result support. */
export class FakeLocalProviderAdapter implements ProviderOperationAdapter {
  readonly adapterId = "fake-local";
  readonly calls: ProviderOperation[] = [];
  async resolveCapabilities(): Promise<ProviderCapabilitySnapshot> {
    return Object.freeze({ scope: Object.freeze({ adapterInstanceId: "fake-local-instance", runtimeVersion: "local-v1", authenticationContext: "none", configurationFingerprint: "fixed" }), claims: Object.freeze(operations.map((capability) => Object.freeze({ capability, state: capability === "health" || capability === "generation" || capability === "cancellation" ? "supported" as const : "unsupported" as const, degradation: "local_surface_unavailable" }))) });
  }
  async invoke(operation: ProviderOperation, request: unknown): Promise<unknown> { this.calls.push(operation); return Object.freeze({ operation, request, implementation: "local-shaped" }); }
}
