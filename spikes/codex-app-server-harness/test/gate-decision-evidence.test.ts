import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { createSyntheticGateEvidenceForTest, loadValidatedGateEvidence, reduceGateDecision } from "../src/evidence/gate-decision-evidence-loader.ts";
import { writeGateDecisionEvidence } from "../src/evidence/gate-decision-evidence-recorder.ts";

const approvedRoot = new URL("../evidence/current-reject-prerequisites/", import.meta.url);

test("approved on-disk prerequisite evidence reduces to the current non-authorizing reject", async () => {
  const bundle = await loadValidatedGateEvidence(approvedRoot.pathname);
  const decision = reduceGateDecision(bundle);
  assert.equal(decision.decision, "reject");
  assert.deepEqual(decision.failedGates, ["authentication", "structured_output", "containment", "provider_cleanup"]);
  assert.deepEqual(decision.stopConditions, ["containment_boundary_unavailable", "live_auth_unproven", "live_codex_cleanup_unproven", "live_quality_unproven"]);
});

test("synthetic reducer coverage cannot publish an authorization", async () => {
  const allPassed = createSyntheticGateEvidenceForTest(Object.fromEntries(["protocol", "authentication", "allowance", "structured_output", "containment", "conversation_ownership", "provider_cleanup", "provider_neutrality"].map((gate) => [gate, { schemaVersion: 1, gate, result: "passed", safeCode: null, reproductionCommand: "npm run test:synthetic" }])) as Parameters<typeof createSyntheticGateEvidenceForTest>[0]);
  assert.equal(reduceGateDecision(allPassed).decision, "proceed");
  const constrained = createSyntheticGateEvidenceForTest({ ...allPassed.records, protocol: { ...allPassed.records.protocol, result: "constrained", safeCode: "fixed_limit" } });
  assert.equal(reduceGateDecision(constrained).decision, "proceed_with_constraints");
  await assert.rejects(writeGateDecisionEvidence(allPassed, await mkdtemp(join(tmpdir(), "projectos-gate-synthetic-"))), /unvalidated_evidence_bundle/u);
});

test("reducer and writer reject a structurally forged bundle and publish only a complete pre-rename summary", async () => {
  const output = await mkdtemp(join(tmpdir(), "projectos-gate-decision-"));
  const bundle = await loadValidatedGateEvidence(approvedRoot.pathname);
  await assert.throws(() => reduceGateDecision({ ...bundle }), /unvalidated_evidence_bundle/u);
  const publication = await writeGateDecisionEvidence(bundle, output, "gate-test");
  assert.equal(publication.durability, "durable"); assert.equal(publication.decision, "reject");
  const text = await readFile(publication.path, "utf8");
  assert.match(text, /"decision": "reject"/u); assert.doesNotMatch(text, /credential|content|opaque|\/Users/iu);
});
