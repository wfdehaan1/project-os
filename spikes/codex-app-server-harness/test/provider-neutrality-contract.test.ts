import assert from "node:assert/strict";
import test from "node:test";
import { ProviderJobCoordinator } from "../src/core/provider-job-coordinator.ts";
import { ProviderRegistry } from "../src/core/provider-registry.ts";
import { runCapabilityWorkflow } from "../src/core/provider-contract-workflow.ts";
import { FakeCodexProviderAdapter } from "./fixtures/fake-codex-provider-adapter.ts";
import { FakeLocalProviderAdapter } from "./fixtures/fake-local-provider-adapter.ts";

test("structurally different fakes use the same fixed ProjectOS workflow and declare degradation", async () => {
  const codex = new FakeCodexProviderAdapter(); const local = new FakeLocalProviderAdapter();
  const codexRegistry = await ProviderRegistry.bind(codex); const localRegistry = await ProviderRegistry.bind(local);
  assert.equal((await runCapabilityWorkflow(codexRegistry, "generation", ["generation"], { id: "one" })).status, "executed");
  const blocked = await runCapabilityWorkflow(localRegistry, "streaming", ["streaming"], { id: "one" });
  assert.deepEqual(blocked, { operation: "streaming", status: "degraded", degradation: "capability_local_surface_unavailable", value: null });
  assert.deepEqual(local.calls, []);
});

test("operation-bound lease checks current scope and capability immediately before the only effect", async () => {
  const adapter = new FakeCodexProviderAdapter(); const registry = await ProviderRegistry.bind(adapter);
  const generation = registry.acquireLease("generation", ["generation"]);
  await assert.rejects(registry.dispatch({ ...generation, operation: "health" }, {}), /invalid_dispatch_lease/u);
  assert.deepEqual(adapter.calls, []);
  adapter.driftScope(); await assert.rejects(registry.dispatch(generation, {}), /capability_scope_drift/u);
  assert.deepEqual(adapter.calls, []);
});

test("durable coordinator binds completions to the active attempt and canonical revision", async () => {
  const coordinator = new ProviderJobCoordinator(); await coordinator.create("job-one", "revision-one");
  await assert.rejects(coordinator.create("job-one", "revision-one"), /duplicate_active_job/u);
  const accepted = { outcome: "reject", stopConditions: ["validation"] } as const;
  assert.equal(await coordinator.complete({ jobId: "job-one", attempt: 2, canonicalRevision: "revision-one", result: accepted }), null);
  assert.equal(await coordinator.complete({ jobId: "job-one", attempt: 1, canonicalRevision: "revision-two", result: accepted }), null);
  const [completed, cancelled] = await Promise.all([coordinator.complete({ jobId: "job-one", attempt: 1, canonicalRevision: "revision-one", result: accepted }), coordinator.cancel("job-one", 1)]);
  assert.equal(Boolean(completed) !== Boolean(cancelled), true);
  assert.deepEqual(coordinator.activeJobIds(), []);
  await coordinator.create("job-one", "revision-one", 2);
});
