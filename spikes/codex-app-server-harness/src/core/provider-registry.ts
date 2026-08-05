import type {
  ProviderCapabilityClaim,
  ProviderCapabilitySnapshot,
  ProviderCapabilityScope,
  ProviderOperation,
  ProviderOperationAdapter,
} from "./ai-provider-port.ts";

const operations: readonly ProviderOperation[] = ["health", "generation", "streaming", "cancellation", "structured_result", "session_cleanup"];
const leaseBrand = new WeakSet<object>();

export interface DispatchLease {
  readonly operation: ProviderOperation;
  readonly mandatoryCapabilities: readonly ProviderOperation[];
  readonly scope: ProviderCapabilityScope;
}

/** A single adapter binding. It deliberately has no replacement method. */
export class ProviderRegistry {
  readonly #adapter: ProviderOperationAdapter;
  readonly #initial: ProviderCapabilitySnapshot;

  private constructor(adapter: ProviderOperationAdapter, initial: ProviderCapabilitySnapshot) {
    this.#adapter = adapter;
    this.#initial = initial;
  }

  static async bind(adapter: ProviderOperationAdapter): Promise<ProviderRegistry> {
    const initial = freezeSnapshot(await adapter.resolveCapabilities());
    return new ProviderRegistry(adapter, initial);
  }

  capabilitySnapshot(): ProviderCapabilitySnapshot { return this.#initial; }

  acquireLease(operation: ProviderOperation, mandatoryCapabilities: readonly ProviderOperation[]): DispatchLease {
    if (!operations.includes(operation) || mandatoryCapabilities.length === 0 || new Set(mandatoryCapabilities).size !== mandatoryCapabilities.length || !mandatoryCapabilities.includes(operation)) throw new Error("invalid_dispatch_lease");
    for (const capability of mandatoryCapabilities) if (!operations.includes(capability)) throw new Error("invalid_dispatch_lease");
    const lease = Object.freeze({ operation, mandatoryCapabilities: Object.freeze([...mandatoryCapabilities]), scope: this.#initial.scope });
    leaseBrand.add(lease);
    return lease;
  }

  /**
   * Resolve and compare the active snapshot immediately before the only
   * adapter call. There is no callback or generic alternate dispatch route.
   */
  async dispatch(lease: DispatchLease, request: unknown): Promise<unknown> {
    if (!leaseBrand.has(lease) || lease.scope !== this.#initial.scope || !operations.includes(lease.operation)) throw new Error("invalid_dispatch_lease");
    const active = freezeSnapshot(await this.#adapter.resolveCapabilities());
    if (!sameScope(this.#initial.scope, active.scope)) throw new Error("capability_scope_drift");
    for (const capability of lease.mandatoryCapabilities) {
      const claim = active.claims.find((candidate) => candidate.capability === capability);
      if (!claim || claim.state !== "supported") throw new Error(`capability_${claim?.degradation ?? claim?.state ?? "unknown"}`);
    }
    // Keep this immediately adjacent to the checks above: future effects must
    // not be inserted between verification and invocation.
    return this.#adapter.invoke(lease.operation, request);
  }
}

function freezeSnapshot(value: ProviderCapabilitySnapshot): ProviderCapabilitySnapshot {
  if (!value || !sameShapeScope(value.scope) || !Array.isArray(value.claims) || value.claims.length !== operations.length) throw new Error("invalid_capability_snapshot");
  const claims = value.claims.map((claim) => freezeClaim(claim));
  if (new Set(claims.map((claim) => claim.capability)).size !== operations.length || claims.some((claim) => !operations.includes(claim.capability))) throw new Error("ambiguous_capability_claims");
  const scope = Object.freeze({ ...value.scope });
  return Object.freeze({ scope, claims: Object.freeze(claims) });
}

function freezeClaim(value: ProviderCapabilityClaim): ProviderCapabilityClaim {
  if (!value || !operations.includes(value.capability) || !["supported", "unsupported", "temporarily_unavailable", "unknown"].includes(value.state) || !safeLabel(value.degradation)) throw new Error("invalid_capability_claim");
  return Object.freeze({ ...value });
}
function sameShapeScope(value: ProviderCapabilityScope): boolean { return [value?.adapterInstanceId, value?.runtimeVersion, value?.authenticationContext, value?.configurationFingerprint].every(safeLabel); }
function safeLabel(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$/u.test(value); }
function sameScope(left: ProviderCapabilityScope, right: ProviderCapabilityScope): boolean { return left.adapterInstanceId === right.adapterInstanceId && left.runtimeVersion === right.runtimeVersion && left.authenticationContext === right.authenticationContext && left.configurationFingerprint === right.configurationFingerprint; }
