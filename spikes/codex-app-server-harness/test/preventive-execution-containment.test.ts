import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import { assertContainmentThreadStart, assertContainmentTurnStart } from "../src/adapters/codex/protocol-contract.ts";
import {
  consumePreventiveExecutionAttestation,
  createContainmentEnvelope,
} from "../src/core/preventive-execution-containment.ts";
import { writeContainmentEvidence } from "../src/evidence/containment-evidence-recorder.ts";

const digest = "a".repeat(64);

test("the envelope excludes inherited capabilities, writes, and non-preview sources", () => {
  const envelope = createContainmentEnvelope([digest]);
  assert.equal(envelope.writableRootCount, 0);
  assert.equal(envelope.approvalPolicy, "never");
  assert.equal(envelope.experimentalApi, false);
  assert.deepEqual(envelope.instructionSources, ["projectos_context_preview"]);
  assert.deepEqual(envelope.disabledCapabilities, ["apps", "connectors", "dynamic_tools", "mcp", "plugins", "skills", "tools"]);
  assertContainmentThreadStart({ approvalPolicy: "never", experimentalApi: false, writableRootCount: 0, instructionSources: ["projectos_context_preview"] });
  assertContainmentTurnStart({ approvalPolicy: "never", experimentalApi: false, contextPreviewRecordCount: 1, instructionSources: ["projectos_context_preview"] });
  assert.throws(() => assertContainmentThreadStart({ approvalPolicy: "never", experimentalApi: false, writableRootCount: 1, instructionSources: ["projectos_context_preview"] } as never), /containment_request_rejected/u);
  assert.throws(() => assertContainmentTurnStart({ approvalPolicy: "never", experimentalApi: true, contextPreviewRecordCount: 1, instructionSources: ["projectos_context_preview"] } as never), /containment_request_rejected/u);
  assert.throws(() => assertContainmentThreadStart({ approvalPolicy: "never", experimentalApi: false, writableRootCount: 0, instructionSources: ["projectos_context_preview"], tools: ["unexpected"] } as never), /containment_request_rejected/u);
});

test("an unverified or fabricated containment attestation cannot authorize a turn", () => {
  assert.throws(() => consumePreventiveExecutionAttestation({ attestation: {}, attemptId: "attempt-1", jobId: "job-1", manifestDigest: digest, snapshotDigest: "b".repeat(64) }), /containment_attestation_required/u);
});

test("shipped adapter fails closed before discovery when no externally verified preventive boundary exists", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-containment-evidence-"));
  let discovered = false;
  const adapter = new CodexAppServerAdapter({ evidenceRoot: root, discover: async () => { discovered = true; throw new Error("must not discover"); }, runId: () => "containment-run", correlationId: () => "containment-correlation" });
  const result = await adapter.validatePreventiveExecutionContainment({ jobId: "containment-job", live: true });
  assert.equal(result.ok, false); assert.equal(result.code, "containment_boundary_unavailable"); assert.equal(discovered, false);
  const evidence = await readFile(join(root, "containment-run-containment", "containment-summary.json"), "utf8");
  assert.doesNotMatch(evidence, /(?:Users|prompt|payload|secret|https?:)/iu);
});

test("every hostile containment class is rejected before discovery or a provider effect", async () => {
  const fixtures = [
    "prompt-injection", "path-traversal", "symlink-escape", "inherited-mcp",
    "environment-canary", "filesystem-read", "filesystem-write", "web-search",
    "command-attempt", "connector", "tool", "permission-request",
  ];
  for (const fixture of fixtures) {
    const root = await mkdtemp(join(tmpdir(), "projectos-containment-hostile-"));
    let discovered = false;
    const adapter = new CodexAppServerAdapter({
      evidenceRoot: root,
      discover: async () => { discovered = true; throw new Error("must not discover"); },
      runId: () => `hostile-${fixture}`,
      correlationId: () => `hostile-${fixture}`,
    });
    const result = await adapter.validatePreventiveExecutionContainment({
      jobId: `hostile-${fixture}`,
      live: true,
    });
    assert.equal(result.ok, false, fixture);
    assert.equal(discovered, false, fixture);
  }
});

test("containment evidence is atomic and rejects raw or contradictory observations", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-containment-bad-evidence-"));
  await assert.rejects(writeContainmentEvidence({ schemaVersion: 1, runId: "bad-run", correlationId: "bad-correlation", result: "reject", runtimeFingerprint: null, manifestFingerprint: null, allowedReadRootCount: 0, writableRootCount: 0, instructionSources: [], boundary: "unavailable", observations: { allowed_read: "not_run", outside_access: "not_run", mutation: "not_run", capability_effect: "not_run" }, stopConditions: ["raw_payload"], reproductionCommand: "npm run validate:containment" }, root), /evidence_write_failed/u);
  await assert.rejects(writeContainmentEvidence({ schemaVersion: 1, runId: "false-pass", correlationId: "false-pass", result: "proceed", runtimeFingerprint: null, manifestFingerprint: null, allowedReadRootCount: 0, writableRootCount: 0, instructionSources: [], boundary: "unavailable", observations: { allowed_read: "not_run", outside_access: "not_run", mutation: "not_run", capability_effect: "not_run" }, stopConditions: [], reproductionCommand: "npm run validate:containment" }, root), /evidence_write_failed/u);
  assert.equal((await readdir(root)).some((name) => name.includes(".tmp")), false);
  const blocked = join(root, "blocked"); await writeFile(blocked, "x");
  await assert.rejects(writeContainmentEvidence({ schemaVersion: 1, runId: "blocked-run", correlationId: "blocked-correlation", result: "reject", runtimeFingerprint: null, manifestFingerprint: null, allowedReadRootCount: 0, writableRootCount: 0, instructionSources: [], boundary: "unavailable", observations: { allowed_read: "not_run", outside_access: "not_run", mutation: "not_run", capability_effect: "not_run" }, stopConditions: ["containment_boundary_unavailable"], reproductionCommand: "npm run validate:containment" }, blocked), /evidence_write_failed/u);
});
