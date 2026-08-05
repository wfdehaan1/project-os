/**
 * The containment capability is deliberately opaque.  A caller cannot construct
 * one from JSON, copy it between attempts, or turn it into a general provider
 * transport.  It is a one-use proof for the one structured-output validation
 * attempt that produced it.
 */
const attestationBrand: unique symbol = Symbol("projectos.containment-attestation");

export interface ContainmentEnvelope {
  readonly readableRootDigests: readonly string[];
  readonly writableRootCount: 0;
  readonly approvalPolicy: "never";
  readonly experimentalApi: false;
  readonly inheritedConfiguration: "excluded";
  readonly disabledCapabilities: readonly [
    "apps", "connectors", "dynamic_tools", "mcp", "plugins", "skills", "tools",
  ];
  readonly instructionSources: readonly ["projectos_context_preview"];
}

export interface PreventiveContainmentObservation {
  readonly boundary: "stable_runtime_disable" | "verified_macos_boundary";
  readonly allowedRead: "observed";
  readonly outsideRootAccess: "not_observed";
  readonly mutation: "not_observed";
  readonly capabilityEffects: "not_observed";
}

export interface PreventiveExecutionAttestation {
  readonly [attestationBrand]: true;
}

interface AttestationFacts {
  readonly attemptId: string;
  readonly jobId: string;
  readonly manifestDigest: string;
  readonly snapshotDigest: string;
  consumed: boolean;
}

const factsByAttestation = new WeakMap<object, AttestationFacts>();

export function createContainmentEnvelope(readableRootDigests: readonly string[]): ContainmentEnvelope {
  if (readableRootDigests.length === 0 || !readableRootDigests.every(isDigest)) {
    throw new Error("containment_envelope_invalid");
  }
  return Object.freeze({
    readableRootDigests: Object.freeze([...new Set(readableRootDigests)].sort()),
    writableRootCount: 0,
    approvalPolicy: "never",
    experimentalApi: false,
    inheritedConfiguration: "excluded",
    disabledCapabilities: Object.freeze([
      "apps", "connectors", "dynamic_tools", "mcp", "plugins", "skills", "tools",
    ]) as ContainmentEnvelope["disabledCapabilities"],
    instructionSources: Object.freeze(["projectos_context_preview"]) as ContainmentEnvelope["instructionSources"],
  });
}

/** Consumes a proof before the first thread/turn request. */
export function consumePreventiveExecutionAttestation(input: {
  readonly attestation: unknown;
  readonly attemptId: string;
  readonly jobId: string;
  readonly manifestDigest: string;
  readonly snapshotDigest: string;
}): void {
  if (typeof input.attestation !== "object" || input.attestation === null) {
    throw new Error("containment_attestation_required");
  }
  const facts = factsByAttestation.get(input.attestation);
  if (!facts || facts.consumed || facts.attemptId !== input.attemptId || facts.jobId !== input.jobId ||
      facts.manifestDigest !== input.manifestDigest || facts.snapshotDigest !== input.snapshotDigest) {
    throw new Error("containment_attestation_required");
  }
  facts.consumed = true;
}

function isDigest(value: string): boolean { return /^[a-f0-9]{64}$/u.test(value); }
