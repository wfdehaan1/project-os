import type { ChangeProposal, ContextPreview, ProposalArtifactType } from "../../src/core/change-proposal-schema.ts";
import { coordinateStructuredCompletion, createStructuredJobState } from "../../src/core/provider-job-coordinator.ts";
import { evaluateQuality, scoreArtifact, type ArtifactQualityScore } from "../../src/core/quality-score.ts";
import { normalizeStructuredOutput } from "../../src/core/structured-output.ts";

export interface RepresentativeFixture { readonly fixtureId: string; readonly contextPreview: ContextPreview; readonly expectedProposal: ChangeProposal; readonly fakeReply: "expected"; }
export function runFakeStructuredFixture(fixture: RepresentativeFixture, reply: unknown = fixture.expectedProposal) {
  const scores = scoreFixture(fixture.expectedProposal, reply);
  const quality = evaluateQuality(scores);
  const result = normalizeStructuredOutput(fixture.contextPreview, reply, quality);
  return coordinateStructuredCompletion(createStructuredJobState(fixture.fixtureId), { jobId: fixture.fixtureId, attempt: 1, result });
}
function scoreFixture(expected: ChangeProposal, actual: unknown): readonly ArtifactQualityScore[] {
  const proposal = actual as Partial<ChangeProposal>; const actualArtifacts = Array.isArray(proposal.artifacts) ? proposal.artifacts : [];
  return (["fact", "decision", "research", "open_question", "task"] as const).map((type) => {
    const expectedArtifact = expected.artifacts.find((artifact) => artifact.type === type)!;
    const actualArtifact = actualArtifacts.find((artifact) => artifact && typeof artifact === "object" && (artifact as { type?: unknown }).type === type) as ChangeProposal["artifacts"][number] | undefined;
    const matched = actualArtifact !== undefined && actualArtifact.id === expectedArtifact.id && JSON.stringify(actualArtifact.provenance) === JSON.stringify(expectedArtifact.provenance);
    const extra = actualArtifacts.filter((artifact) => artifact && typeof artifact === "object" && (artifact as { type?: unknown }).type === type).length - (actualArtifact ? 1 : 0);
    return scoreArtifact({ type, denominator: 1, truePositives: matched ? 1 : 0, falsePositives: Math.max(0, extra), falseNegatives: matched ? 0 : 1, unsupportedClaims: 0, provenanceFailures: actualArtifact && !matched ? 1 : 0, governingStateOmissions: type === "decision" && JSON.stringify(proposal.governingEffects) !== JSON.stringify(expected.governingEffects) ? 1 : 0, reentryOmissions: type === "task" && JSON.stringify(proposal.reentryEffects) !== JSON.stringify(expected.reentryEffects) ? 1 : 0, correctionEffort: matched ? 0 : 1 });
  });
}
