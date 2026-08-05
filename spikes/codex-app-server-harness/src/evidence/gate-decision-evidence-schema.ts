export const REQUIRED_GATE_IDS = ["protocol", "authentication", "allowance", "structured_output", "containment", "conversation_ownership", "provider_cleanup", "provider_neutrality"] as const;
export type GateId = typeof REQUIRED_GATE_IDS[number];
export type GateResult = "passed" | "constrained" | "failed";
export type GateDecision = "proceed" | "proceed_with_constraints" | "reject";

export interface GateSourceRecord {
  readonly schemaVersion: 1;
  readonly gate: GateId;
  readonly result: GateResult;
  readonly safeCode: string | null;
  readonly reproductionCommand: string;
}

export interface GateSourceManifest {
  readonly schemaVersion: 1;
  readonly records: Readonly<Record<GateId, Readonly<{ readonly file: string; readonly sha256: string; readonly reproductionCommand: string }>>>;
}

export interface GateDecisionEvidence {
  readonly schemaVersion: 1;
  readonly runId: string;
  readonly decision: GateDecision;
  readonly failedGates: readonly GateId[];
  readonly stopConditions: readonly string[];
  readonly sourceManifestSha256: string;
  readonly reproductionCommand: "npm run validate:gate-decision";
}
