import assert from "node:assert/strict";
import { mkdtemp, readFile, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { ProviderCleanupOutbox } from "../src/core/provider-cleanup-outbox.ts";

const fingerprint = `sha256:${"a".repeat(64)}`;
const intent = { id: "cleanup-record", adapterId: "fake", providerProfileId: "profile", authenticationContextFingerprint: fingerprint } as const;
const clock = () => "2026-08-05T12:00:00.000Z";

test("the private outbox persists a content-free create intent before an external effect", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-cleanup-outbox-")); const outbox = await ProviderCleanupOutbox.open(root, { now: clock });
  const created = await outbox.recordCreateIntent(intent);
  assert.equal(created.lifecycle, "create_intent"); assert.equal(created.opaqueSessionId, null);
  const reloaded = await ProviderCleanupOutbox.open(root, { now: clock }); assert.deepEqual(reloaded.list(), [created]);
  const text = await readFile(join(root, "provider-cleanup-outbox.json"), "utf8"); assert.doesNotMatch(text, /project content|canonical|conversation|binding|preview|credential|prompt|result/iu);
  assert.equal((await stat(join(root, "provider-cleanup-outbox.json"))).mode & 0o077, 0);
});

test("terminal records retain only a minimal receipt and duplicate terminal actions are idempotent", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-cleanup-terminal-")); const outbox = await ProviderCleanupOutbox.open(root, { now: clock });
  await outbox.recordCreateIntent(intent); await outbox.bindCreatedSession(intent.id, "opaque-1"); await outbox.recordLocalDeletion(intent.id);
  const terminal = await outbox.recordTerminal(intent.id, "confirmed"); const duplicate = await outbox.recordTerminal(intent.id, "absent");
  assert.equal(terminal.lifecycle, "confirmed"); assert.deepEqual(duplicate, terminal); assert.deepEqual(terminal.receipt, { outcome: "confirmed", completedAt: "2026-08-05T12:00:00.000Z" });
});

test("unknown pre-create state cannot become a terminal cleanup claim", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-cleanup-pending-")); const outbox = await ProviderCleanupOutbox.open(root, { now: clock });
  await outbox.recordCreateIntent(intent);
  await assert.rejects(outbox.recordTerminal(intent.id, "absent"), /cleanup_outbox_transition_invalid/u);
});

test("two stale handles preserve independent create intents", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-cleanup-concurrent-")); const first = await ProviderCleanupOutbox.open(root, { now: clock }); const second = await ProviderCleanupOutbox.open(root, { now: clock });
  await first.recordCreateIntent(intent); await second.recordCreateIntent({ ...intent, id: "cleanup-record-two" });
  assert.deepEqual((await ProviderCleanupOutbox.open(root, { now: clock })).list().map((entry) => entry.id).sort(), ["cleanup-record", "cleanup-record-two"]);
});
