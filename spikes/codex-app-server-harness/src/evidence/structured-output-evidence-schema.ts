import type { ArtifactQualityScore } from "../core/quality-score.ts";

/** Strictly metric-only retention. Fixture/project names and provider output are never evidence. */
export interface StructuredOutputValidationEvidence {
  readonly schemaVersion: 1;
  readonly runId: string;
  readonly correlationId: string;
  readonly result: "proceed" | "reject";
  readonly scorePercent: number | null;
  readonly scores: readonly ArtifactQualityScore[];
  readonly stopConditions: readonly string[];
  readonly containment: "unavailable" | "attested";
  readonly reproductionCommand: "npm run validate:structured-output";
}
