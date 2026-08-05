import { validateChangeProposal, type ChangeProposal, type ContextPreview } from "./change-proposal-schema.ts";
import type { QualityGateResult } from "./quality-score.ts";

export type StructuredOutputTerminalResult =
  | Readonly<{ readonly outcome: "accepted"; readonly proposal: ChangeProposal; readonly quality: QualityGateResult }>
  | Readonly<{ readonly outcome: "reject"; readonly stopConditions: readonly string[] }>;

export function normalizeStructuredOutput(preview: ContextPreview, raw: unknown, quality: QualityGateResult): StructuredOutputTerminalResult {
  if (!validateChangeProposal(raw)) return rejected("malformed_structured_output");
  if (quality.outcome !== "proceed") return Object.freeze({ outcome: "reject", stopConditions: quality.stopConditions });
  const allowed = new Map(preview.records.map((record) => [record.id, record.type]));
  if (raw.artifacts.some((artifact) => artifact.provenance.some((id) => allowed.get(id) !== artifact.type))) return rejected("invalid_provenance");
  return freezeTerminal({ outcome: "accepted", proposal: raw, quality });
}
export function rejected(stop: string): StructuredOutputTerminalResult { return Object.freeze({ outcome: "reject", stopConditions: Object.freeze([stop]) }); }
export function freezeTerminal(result: StructuredOutputTerminalResult): StructuredOutputTerminalResult {
  if (result.outcome === "reject") return Object.freeze({ outcome: "reject", stopConditions: Object.freeze([...result.stopConditions]) });
  const proposal = result.proposal;
  return Object.freeze({ outcome: "accepted", proposal: Object.freeze({ proposalId: proposal.proposalId, artifacts: Object.freeze(proposal.artifacts.map((artifact) => Object.freeze({ id: artifact.id, type: artifact.type, provenance: Object.freeze([...artifact.provenance]) }))), relationships: Object.freeze(proposal.relationships.map((relationship) => Object.freeze({ ...relationship }))), governingEffects: Object.freeze([...proposal.governingEffects]), reentryEffects: Object.freeze([...proposal.reentryEffects]) }), quality: Object.freeze({ outcome: result.quality.outcome, scorePercent: result.quality.scorePercent, stopConditions: Object.freeze([...result.quality.stopConditions]), scores: Object.freeze(result.quality.scores.map((score) => Object.freeze({ ...score }))) }) });
}
