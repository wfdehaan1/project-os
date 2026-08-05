import assert from "node:assert/strict";
import { Ajv2020 } from "ajv/dist/2020.js";
import { readFile, mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { approveContextPreview, createFreshProviderSessionBinding } from "../src/core/conversation-ownership.ts";
import { exportPortableProject, parsePortableProjectExport, portableProjectDigest, type PortableProjectExport, type ProjectOwnedState } from "../src/core/project-export.ts";
import { preflightPortableProject, restorePortableProject } from "../src/core/project-restore.ts";
import { writeConversationOwnershipEvidence } from "../src/evidence/conversation-ownership-evidence-recorder.ts";

async function fixture(): Promise<PortableProjectExport> { return parsePortableProjectExport(JSON.parse(await readFile(new URL("./fixtures/portable-conversation-project.json", import.meta.url), "utf8"))); }

test("export contains canonical ProjectOS content and excludes the replaceable binding", async () => {
  const portable = await fixture(); const conversation = portable.project.conversations[0]!;
  const state: ProjectOwnedState = { ...portable.project, bindings: [createFreshProviderSessionBinding({ conversation, adapterId: "codex", opaqueSessionHandle: "opaque-session-1", approval: approveContextPreview({ conversation, contextPreviewId: "preview-export" }) })] };
  const exported = exportPortableProject(state); const serialized = JSON.stringify(exported);
  assert.equal("bindings" in exported.project, false);
  assert.doesNotMatch(serialized, /opaque-session-1|codex|session/iu);
  assert.equal(exported.project.conversations[0]!.id, "conversation-source");
  assert.throws(() => parsePortableProjectExport({ ...exported, project: { ...exported.project, bindings: [] } }), /portable_project_invalid/u);
  assert.throws(() => exportPortableProject({ ...state, bindings: [{ ...state.bindings[0]!, credential: "must-not-export" }] as never }), /project_state_invalid/u);
  assert.throws(() => exportPortableProject({ ...state, bindings: [state.bindings[0]!, state.bindings[0]!] }), /project_state_invalid/u);
});

test("offline restore performs one complete map, preserves relationships and has no binding", async () => {
  const portable = await fixture(); const sourceJson = JSON.stringify(portable);
  const restored = restorePortableProject(portable);
  assert.equal(restored.project.bindings.length, 0);
  assert.notEqual(restored.project.id, portable.project.id);
  assert.equal(restored.project.conversations[0]!.transcript[0]!.text, portable.project.conversations[0]!.transcript[0]!.text);
  assert.equal(restored.project.relationships[0]!.fromId, restored.project.conversations[0]!.id);
  assert.equal(restored.project.relationships[0]!.toId, restored.project.rationales[0]!.id);
  assert.equal(restored.project.provenances[0]!.sourceId, restored.project.sources[0]!.id);
  assert.equal(restored.importProvenance.sourceProjectId, "project-source");
  assert.equal(exportPortableProject(restored.project).project.importProvenance?.originalIds.length, 8);
  assert.equal(JSON.stringify(portable), sourceJson);
  const repeat = restorePortableProject(portable, { makeId: (sourceId, ordinal) => `copy-${ordinal}-${sourceId}` });
  assert.notEqual(repeat.project.id, restored.project.id);
  const defaultRepeat = restorePortableProject(portable);
  assert.notEqual(defaultRepeat.project.id, restored.project.id);
});

test("corrupt, duplicate, incomplete, and collision-prone restores have no partial result", async () => {
  const portable = await fixture();
  assert.throws(() => restorePortableProject({ ...portable, project: { ...portable.project, sources: [...portable.project.sources, portable.project.sources[0]] } }), /portable_project_invalid/u);
  assert.throws(() => restorePortableProject(portable, { makeId: () => "same-id" }), /restore_map_invalid/u);
  assert.throws(() => restorePortableProject(portable, { makeId: (sourceId) => sourceId }), /restore_map_invalid/u);
  assert.throws(() => restorePortableProject({ schemaVersion: 2, project: portable.project }), /portable_project_invalid/u);
});

test("v0 metadata is inert and a later approved start creates the new binding", async () => {
  const portable = await fixture();
  const legacy = preflightPortableProject({ schemaVersion: 0, project: portable.project, adapterMetadata: { codex: { session: "cannot-reattach" } } });
  const restored = restorePortableProject(legacy); const conversation = restored.project.conversations[0]!;
  assert.equal(restored.project.bindings.length, 0);
  const binding = createFreshProviderSessionBinding({ conversation, adapterId: "codex", opaqueSessionHandle: "new-opaque-2", approval: approveContextPreview({ conversation, contextPreviewId: "preview-restored" }) });
  assert.equal(binding.conversationId, conversation.id);
});

test("structural evidence is atomic, content-free, and digest-only", async () => {
  const portable = await fixture(); const restored = restorePortableProject(portable); const root = await mkdtemp(join(tmpdir(), "projectos-ownership-evidence-"));
  const file = await writeConversationOwnershipEvidence({ schemaVersion: 1, runId: "ownership-run", correlationId: "ownership-correlation", outcome: "proceed", exportDigest: portableProjectDigest(portable), restoreDigest: portableProjectDigest(exportPortableProject(restored.project)), counts: { projects: 1, conversations: 1, transcriptEntries: 1, acceptedHistoryEntries: 1, rationales: 1, provenances: 1, sources: 1, relationships: 1 }, checks: ["binding_excluded", "offline_restore", "remap_complete", "fresh_binding_required"], stopConditions: [], reproductionCommand: "npm run validate:conversation-ownership" }, root);
  const text = await readFile(file, "utf8"); assert.doesNotMatch(text, /project-source|local truth|opaque|codex|session/iu);
  const schema = JSON.parse(await readFile(new URL("../evidence/conversation-ownership-validation-run.schema.json", import.meta.url), "utf8")) as object;
  assert.equal(new Ajv2020({ strict: false }).compile(schema)(JSON.parse(text)), true);
});

test("reject evidence requires a structural stop condition before publication", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-ownership-reject-"));
  await assert.rejects(writeConversationOwnershipEvidence({ schemaVersion: 1, runId: "ownership-reject", correlationId: "ownership-reject-correlation", outcome: "reject", exportDigest: null, restoreDigest: null, counts: { projects: 0, conversations: 0, transcriptEntries: 0, acceptedHistoryEntries: 0, rationales: 0, provenances: 0, sources: 0, relationships: 0 }, checks: [], stopConditions: [], reproductionCommand: "npm run validate:conversation-ownership" }, root), /evidence_write_failed/u);
});

test("portable digests normalize unordered project collections while preserving local transcript order", async () => {
  const portable = await fixture();
  const withSecondConversation = parsePortableProjectExport({ ...portable, project: { ...portable.project, conversations: [...portable.project.conversations, { id: "conversation-second", version: 1, transcript: [], acceptedHistory: [] }] } });
  const reordered = parsePortableProjectExport({ ...withSecondConversation, project: { ...withSecondConversation.project, conversations: [...withSecondConversation.project.conversations].reverse() } });
  assert.equal(portableProjectDigest(withSecondConversation), portableProjectDigest(reordered));
});
