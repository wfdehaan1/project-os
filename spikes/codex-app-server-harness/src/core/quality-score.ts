import type { ProposalArtifactType } from "./change-proposal-schema.ts";

export const QUALITY_THRESHOLD_PERCENT = 85;
export interface ArtifactQualityScore {
  readonly type: ProposalArtifactType;
  readonly denominator: number;
  readonly truePositives: number;
  readonly falsePositives: number;
  readonly falseNegatives: number;
  readonly unsupportedClaims: number;
  readonly provenanceFailures: number;
  readonly governingStateOmissions: number;
  readonly reentryOmissions: number;
  readonly correctionEffort: number;
  readonly precisionPercent: number;
  readonly recallPercent: number;
}
export interface QualityGateResult { readonly outcome: "proceed" | "reject"; readonly scorePercent: number; readonly stopConditions: readonly string[]; readonly scores: readonly ArtifactQualityScore[]; }

export function scoreArtifact(input: Omit<ArtifactQualityScore, "precisionPercent" | "recallPercent">): ArtifactQualityScore {
  if (!Number.isSafeInteger(input.denominator) || input.denominator < 1 || [input.truePositives, input.falsePositives, input.falseNegatives, input.unsupportedClaims, input.provenanceFailures, input.governingStateOmissions, input.reentryOmissions, input.correctionEffort].some((value) => !Number.isSafeInteger(value) || value < 0) || input.truePositives + input.falseNegatives !== input.denominator) throw new Error("invalid_quality_denominator");
  const precision = input.truePositives + input.falsePositives === 0 ? 0 : (input.truePositives / (input.truePositives + input.falsePositives)) * 100;
  return Object.freeze({ ...input, precisionPercent: round(precision), recallPercent: round((input.truePositives / input.denominator) * 100) });
}
export function evaluateQuality(scores: readonly ArtifactQualityScore[]): QualityGateResult {
  if (scores.length !== 5 || new Set(scores.map((score) => score.type)).size !== 5 || !scores.every(validScore)) throw new Error("incomplete_quality_denominator");
  const denominator = scores.reduce((sum, score) => sum + score.denominator, 0); const correct = scores.reduce((sum, score) => sum + score.truePositives, 0); const falsePositives = scores.reduce((sum, score) => sum + score.falsePositives, 0);
  // A plausible unsupported extra lowers the gate even though recall remains separately visible.
  const scorePercent = round((correct / (denominator + falsePositives)) * 100); const stops: string[] = [];
  if (scorePercent < QUALITY_THRESHOLD_PERCENT) stops.push("quality_below_85_percent");
  if (scores.some((score) => score.unsupportedClaims > 0)) stops.push("unsupported_claim");
  if (scores.some((score) => score.provenanceFailures > 0)) stops.push("invalid_provenance");
  if (scores.some((score) => score.governingStateOmissions > 0)) stops.push("governing_state_omission");
  if (scores.some((score) => score.reentryOmissions > 0)) stops.push("reentry_omission");
  return Object.freeze({ outcome: stops.length === 0 ? "proceed" : "reject", scorePercent, stopConditions: Object.freeze(stops), scores: Object.freeze(scores.map((score) => Object.freeze({ ...score }))) });
}
function round(value: number): number { return Math.round(value * 100) / 100; }
function validScore(score: ArtifactQualityScore): boolean {
  const keys = Object.keys(score).sort(); const expected = ["correctionEffort", "denominator", "falseNegatives", "falsePositives", "governingStateOmissions", "precisionPercent", "provenanceFailures", "recallPercent", "reentryOmissions", "truePositives", "type", "unsupportedClaims"];
  if (keys.length !== expected.length || !keys.every((key, index) => key === expected[index]) || !["fact", "decision", "research", "open_question", "task"].includes(score.type)) return false;
  const values = [score.denominator, score.truePositives, score.falsePositives, score.falseNegatives, score.unsupportedClaims, score.provenanceFailures, score.governingStateOmissions, score.reentryOmissions, score.correctionEffort];
  if (!values.every((value) => Number.isSafeInteger(value) && value >= 0) || score.denominator < 1 || score.truePositives + score.falseNegatives !== score.denominator) return false;
  return score.precisionPercent === round(score.truePositives + score.falsePositives === 0 ? 0 : (score.truePositives / (score.truePositives + score.falsePositives)) * 100) && score.recallPercent === round((score.truePositives / score.denominator) * 100);
}
