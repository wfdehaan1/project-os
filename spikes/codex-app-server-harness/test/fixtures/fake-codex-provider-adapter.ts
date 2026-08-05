import type { ProviderCapabilitySnapshot, ProviderOperation, ProviderOperationAdapter } from "../../src/core/ai-provider-port.ts";

const operations = ["health", "generation", "streaming", "cancellation", "structured_result", "session_cleanup"] as const;

/** Codex-shaped deterministic fake: all ProjectOS operations are available. */
export class FakeCodexProviderAdapter implements ProviderOperationAdapter {
  readonly adapterId = "fake-codex";
  readonly calls: ProviderOperation[] = [];
  #snapshot: ProviderCapabilitySnapshot = snapshot("fake-codex-instance", operations);
  async resolveCapabilities(): Promise<ProviderCapabilitySnapshot> { return this.#snapshot; }
  async invoke(operation: ProviderOperation, request: unknown): Promise<unknown> { this.calls.push(operation); return Object.freeze({ operation, request, implementation: "codex-shaped" }); }
  driftScope(): void { this.#snapshot = snapshot("replacement-instance", operations); }
}
function snapshot(instance: string, supported: readonly ProviderOperation[]): ProviderCapabilitySnapshot { return Object.freeze({ scope: Object.freeze({ adapterInstanceId: instance, runtimeVersion: "fake-v1", authenticationContext: "fake-context", configurationFingerprint: "fake-config" }), claims: Object.freeze(operations.map((capability) => Object.freeze({ capability, state: supported.includes(capability) ? "supported" as const : "unsupported" as const, degradation: supported.includes(capability) ? "available" : "declared_unavailable" }))) }); }
