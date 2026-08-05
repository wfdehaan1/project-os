import assert from "node:assert/strict";
import { Ajv2020 } from "ajv/dist/2020.js";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { writeProviderCleanupEvidence } from "../src/evidence/provider-cleanup-evidence-recorder.ts";

const evidence = { schemaVersion: 1, runId: "cleanup-run", correlationId: "cleanup-correlation", decision: "reject", counts: { created: 2, confirmed: 1, absent: 1, pending: 0, reauthRequired: 0, ledgerGaps: 0, rolloutMetadata: 0 }, checks: ["intent_before_create", "crash_reconciliation", "local_erasure_separate", "managed_metadata_removed", "sanitized_aggregate"], stopConditions: ["live_codex_cleanup_unproven", "containment_boundary_unavailable"], reproductionCommand: "npm run validate:provider-cleanup" } as const;

test("cleanup evidence is atomic, aggregate-only, and records the mandatory reject conclusion", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-cleanup-evidence-")); const file = await writeProviderCleanupEvidence(evidence, root); const text = await readFile(file, "utf8");
  assert.doesNotMatch(text, /opaque|profile|sha256|credential|content|session|\/Users/iu);
  const schema = JSON.parse(await readFile(new URL("../evidence/provider-cleanup-validation-run.schema.json", import.meta.url), "utf8")) as object;
  assert.equal(new Ajv2020({ strict: false }).compile(schema)(JSON.parse(text)), true);
});

test("evidence refuses canaries, incomplete accounting, and a missing live-contract stop condition", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-cleanup-evidence-reject-"));
  await assert.rejects(writeProviderCleanupEvidence({ ...evidence, counts: { ...evidence.counts, ledgerGaps: 1 } }, root), /evidence_write_failed/u);
  await assert.rejects(writeProviderCleanupEvidence({ ...evidence, stopConditions: ["containment_boundary_unavailable"] }, root), /evidence_write_failed/u);
  await assert.rejects(writeProviderCleanupEvidence({ ...evidence, runId: "session-canary" }, root), /evidence_write_failed/u);
});
