import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { parseSupportedRuntimeManifest } from "../src/adapters/codex/protocol-contract.ts";
import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import { validateChangeProposal, type ChangeProposal, type ContextPreview } from "../src/core/change-proposal-schema.ts";
import { coordinateStructuredCompletion, createStructuredJobState } from "../src/core/provider-job-coordinator.ts";
import { evaluateQuality, scoreArtifact } from "../src/core/quality-score.ts";
import { normalizeStructuredOutput, rejected } from "../src/core/structured-output.ts";
import { writeStructuredOutputEvidence } from "../src/evidence/structured-output-evidence-recorder.ts";
import { runFakeStructuredFixture, type RepresentativeFixture } from "./fixtures/fake-structured-output-runner.ts";

const types = ["fact", "decision", "research", "open_question", "task"] as const;
async function fixture(name: string): Promise<RepresentativeFixture> { return JSON.parse(await readFile(new URL(`./fixtures/representative-project-work/${name}.json`, import.meta.url), "utf8")) as RepresentativeFixture; }

test("fake-backed representative fixtures derive fixture-specific proposals, metrics, and one pending proposal", async () => {
  for (const name of ["garden-office", "used-car", "technical-supersession"]) {
    const value = await fixture(name); const state = runFakeStructuredFixture(value);
    assert.equal(value.contextPreview.records.length, 5); assert.deepEqual(value.contextPreview.records.map((record) => record.type), [...types]);
    assert.equal(state.terminal?.outcome, "accepted"); assert.equal(state.pendingProposal?.proposal.proposalId, value.expectedProposal.proposalId);
    assert.equal(state.terminal?.outcome === "accepted" ? state.terminal.quality.scorePercent : 0, 100);
  }
});

test("typed preview provenance, raw mutation, and cross-job/duplicate completion cannot alter accepted state", async () => {
  const value = await fixture("garden-office"); const raw = structuredClone(value.expectedProposal);
  assert.equal(validateChangeProposal(raw), true);
  const quality = evaluateQuality(types.map((type) => scoreArtifact({ type, denominator: 1, truePositives: 1, falsePositives: 0, falseNegatives: 0, unsupportedClaims: 0, provenanceFailures: 0, governingStateOmissions: 0, reentryOmissions: 0, correctionEffort: 0 })));
  const wrongTyped = structuredClone(raw); (wrongTyped.artifacts[0] as { type: "fact" | "decision" | "research" | "open_question" | "task" }).type = "decision";
  assert.equal(normalizeStructuredOutput(value.contextPreview, wrongTyped, quality).outcome, "reject");
  const accepted = normalizeStructuredOutput(value.contextPreview, raw, quality); assert.equal(accepted.outcome, "accepted");
  const state = coordinateStructuredCompletion(createStructuredJobState("job-a"), { jobId: "job-a", attempt: 1, result: accepted });
  (raw.artifacts[0]!.provenance as string[])[0] = "changed"; assert.equal(state.pendingProposal?.proposal.artifacts[0]?.provenance[0], "garden-fact");
  assert.equal(Object.isFrozen(state.pendingProposal?.proposal.artifacts[0]?.provenance), true);
  assert.equal(coordinateStructuredCompletion(state, { jobId: "other", attempt: 1, result: rejected("malformed_structured_output") }), state);
  assert.equal(coordinateStructuredCompletion(state, { jobId: "job-a", attempt: 1, result: rejected("malformed_structured_output") }), state);
});

test("fixture-specific malformed, partial, unsupported, governing, and re-entry paths reject", async () => {
  const value = await fixture("used-car");
  assert.equal(runFakeStructuredFixture(value, { proposalId: "partial" }).pendingProposal, null);
  const missingDecision = structuredClone(value.expectedProposal) as unknown as { artifacts: ChangeProposal["artifacts"][number][] }; missingDecision.artifacts = missingDecision.artifacts.filter((artifact) => artifact.type !== "decision");
  assert.equal(runFakeStructuredFixture(value, missingDecision).terminal?.outcome, "reject");
  const missingEffects = structuredClone(value.expectedProposal) as unknown as { governingEffects: string[] }; missingEffects.governingEffects = [];
  assert.equal(runFakeStructuredFixture(value, missingEffects).terminal?.outcome, "reject");
  const extra = structuredClone(value.expectedProposal) as unknown as { artifacts: ChangeProposal["artifacts"][number][] }; extra.artifacts.push({ id: "extra-car-fact", type: "fact", provenance: ["car-fact"] });
  assert.equal(runFakeStructuredFixture(value, extra).terminal?.outcome, "reject");
});

test("quality validates score shape and false positives lower the main quality score", () => {
  const scores = types.map((type) => scoreArtifact({ type, denominator: 10, truePositives: 10, falsePositives: type === "fact" ? 2 : 0, falseNegatives: 0, unsupportedClaims: 0, provenanceFailures: 0, governingStateOmissions: 0, reentryOmissions: 0, correctionEffort: 0 }));
  const quality = evaluateQuality(scores); assert.equal(quality.scorePercent, 96.15); assert.equal(quality.scores[0]?.precisionPercent, 83.33); assert.equal(quality.scores[0]?.recallPercent, 100);
  assert.throws(() => evaluateQuality([{ ...scores[0]!, precisionPercent: 99 }, ...scores.slice(1)]), /incomplete_quality_denominator/u);
});

test("metric-only evidence is atomic and rejects nested score content or extra fields", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-structured-evidence-")); const safeScores = types.map((type) => scoreArtifact({ type, denominator: 1, truePositives: 1, falsePositives: 0, falseNegatives: 0, unsupportedClaims: 0, provenanceFailures: 0, governingStateOmissions: 0, reentryOmissions: 0, correctionEffort: 0 }));
  const path = await writeStructuredOutputEvidence({ schemaVersion: 1, runId: "structured-safe", correlationId: "corr-safe", result: "proceed", scorePercent: 100, scores: safeScores, stopConditions: [], containment: "unavailable", reproductionCommand: "npm run validate:structured-output" }, root);
  assert.doesNotMatch(await readFile(path, "utf8"), /prompt|content|token|https?:\/\//iu);
  const canary = { ...safeScores[0]!, secret: "raw content" };
  await assert.rejects(writeStructuredOutputEvidence({ schemaVersion: 1, runId: "structured-bad", correlationId: "corr-bad", result: "reject", scorePercent: null, scores: [canary] as unknown as typeof safeScores, stopConditions: [], containment: "unavailable", reproductionCommand: "npm run validate:structured-output" }, root), /evidence_write_failed/u);
  assert.equal((await readdir(root)).some((name) => name.includes(".tmp")), false);
});

test("structured manifest is deeply frozen and live validation reports safe evidence failure without dispatch", async () => {
  const manifest = parseSupportedRuntimeManifest(await readFile(new URL("../protocol/supported-runtime-manifest.json", import.meta.url), "utf8"));
  assert.throws(() => { (manifest.structuredOutput!.clientRequests as unknown as string[]).push("model/call"); }, TypeError);
  const root = await mkdtemp(join(tmpdir(), "projectos-structured-deny-")); const blockedRoot = join(root, "not-a-directory"); await writeFile(blockedRoot, "blocked"); let discovered = false;
  const adapter = new CodexAppServerAdapter({ evidenceRoot: blockedRoot, discover: async () => { discovered = true; throw new Error("must not discover"); } });
  const result = await adapter.validateStructuredOutput({ jobId: "job-live", live: true });
  assert.equal(result.code, "evidence_write_failed"); assert.equal(discovered, false); assert.equal(result.providerActionEnabled, false);
});
