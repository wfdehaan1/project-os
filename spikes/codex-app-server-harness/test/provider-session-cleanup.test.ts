import assert from "node:assert/strict";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { ProviderCleanupOutbox } from "../src/core/provider-cleanup-outbox.ts";
import { FakeProviderSessionFilesystem, ProviderSessionCleanupCoordinator } from "../src/core/provider-session-cleanup.ts";

const fingerprint = `sha256:${"b".repeat(64)}`;
const context = { adapterId: "fake", providerProfileId: "profile", authenticationContextFingerprint: fingerprint } as const;
const clock = () => "2026-08-05T12:00:00.000Z";

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "projectos-cleanup-coordinator-")); const outbox = await ProviderCleanupOutbox.open(join(root, "outbox"), { now: clock }); const fake = await FakeProviderSessionFilesystem.open(join(root, "fake"));
  return { root, outbox, fake, coordinator: new ProviderSessionCleanupCoordinator({ outbox, provider: fake, context }) };
}

test("a crash after fake creation binds the intent without deleting an active local session", async () => {
  const { root, outbox, fake } = await fixture(); await outbox.recordCreateIntent({ id: "crash-create", ...context }); await fake.createManagedSession({ cleanupObligationId: "crash-create", providerProfileId: context.providerProfileId, authenticationContextFingerprint: fingerprint });
  const reloaded = await ProviderCleanupOutbox.open(join(root, "outbox"), { now: clock }); const coordinator = new ProviderSessionCleanupCoordinator({ outbox: reloaded, provider: fake, context });
  const entries = await coordinator.reconcile(); assert.equal(entries[0]!.lifecycle, "bound"); assert.deepEqual(await fake.audit(), { created: 1, sessions: 1, rolloutMetadata: 1 });
  let erased = false; await coordinator.recordLocalProjectDeletion({ obligationId: "crash-create", eraseLocalProject: async () => { erased = true; } }); assert.equal(erased, true); const completed = await coordinator.reconcile(); assert.equal(completed[0]!.lifecycle, "confirmed"); assert.deepEqual(await fake.audit(), { created: 1, sessions: 0, rolloutMetadata: 0 });
});

test("a list failure leaves an unknown pre-create intent truthful and pending", async () => {
  const { coordinator, fake, outbox } = await fixture(); await outbox.recordCreateIntent({ id: "unknown-create", ...context }); fake.failNextList("adapter_unavailable");
  assert.equal((await coordinator.reconcile()).find((entry) => entry.id === "unknown-create")!.lifecycle, "create_intent");
});

test("local deletion is independent; offline, context loss, absent, and metadata-removal paths remain truthful", async () => {
  const { coordinator, fake, outbox } = await fixture();
  const first = await coordinator.createWithDurableIntent({ id: "delete-later", createEffect: fake }); await coordinator.recordLocalProjectDeletion({ obligationId: first.id, eraseLocalProject: async () => {} }); fake.failNextDelete("adapter_unavailable");
  assert.equal((await coordinator.reconcile()).find((entry) => entry.id === first.id)!.lifecycle, "delete_pending");
  assert.equal((await coordinator.reconcile()).find((entry) => entry.id === first.id)!.lifecycle, "confirmed");
  const absent = await coordinator.createWithDurableIntent({ id: "already-absent", createEffect: fake }); await coordinator.recordLocalProjectDeletion({ obligationId: absent.id, eraseLocalProject: async () => {} }); await fake.deleteManagedSession({ providerProfileId: context.providerProfileId, authenticationContextFingerprint: fingerprint, managedSource: "projectos_cleanup_outbox_v1", opaqueSessionId: absent.opaqueSessionId! });
  assert.equal((await coordinator.reconcile()).find((entry) => entry.id === absent.id)!.lifecycle, "absent");
  const mismatch = await coordinator.createWithDurableIntent({ id: "wrong-context", createEffect: fake }); const changed = new ProviderSessionCleanupCoordinator({ outbox, provider: fake, context: { ...context, authenticationContextFingerprint: `sha256:${"c".repeat(64)}` } });
  assert.equal((await changed.reconcile()).find((entry) => entry.id === mismatch.id)!.lifecycle, "reauth_required");
});

test("a renamed adapter never receives cleanup work and leaves a recoverable pending obligation", async () => {
  const { coordinator, fake, outbox } = await fixture(); const created = await coordinator.createWithDurableIntent({ id: "renamed-adapter", createEffect: fake });
  const renamed = new ProviderSessionCleanupCoordinator({ outbox, provider: fake, context: { ...context, adapterId: "renamed" } });
  assert.equal((await renamed.reconcile()).find((entry) => entry.id === created.id)!.lifecycle, "delete_pending");
  assert.deepEqual(await fake.audit(), { created: 1, sessions: 1, rolloutMetadata: 1 });
});

test("multiple bindings and a lost delete response remain individually accountable", async () => {
  const { coordinator, fake } = await fixture();
  const first = await coordinator.createWithDurableIntent({ id: "project-a", createEffect: fake }); const second = await coordinator.createWithDurableIntent({ id: "project-b", createEffect: fake });
  await coordinator.recordLocalProjectDeletion({ obligationId: first.id, eraseLocalProject: async () => {} }); await coordinator.recordLocalProjectDeletion({ obligationId: second.id, eraseLocalProject: async () => {} });
  fake.loseNextDeleteResponse(); const pending = await coordinator.reconcile(); assert.equal(pending.find((entry) => entry.id === first.id)!.lifecycle, "delete_pending");
  const finished = await coordinator.reconcile(); assert.deepEqual(finished.map((entry) => entry.lifecycle).sort(), ["absent", "confirmed"]); assert.deepEqual(await fake.audit(), { created: 2, sessions: 0, rolloutMetadata: 0 });
});
