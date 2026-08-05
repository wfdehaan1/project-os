import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import { createFakeRuntimeManifest } from "./fixtures/fake-runtime-manifest.ts";

for (const [behavior, readiness] of [["success", "available"], ["allowance-exhausted", "temporarily_unavailable"]] as const) {
  test(`allowance ${readiness} is normalized from the pinned read-only surface`, async () => {
    const fixture = await createFakeRuntimeManifest(behavior); const evidenceRoot = await mkdtemp(join(tmpdir(), "projectos-allowance-evidence-"));
    const adapter = new CodexAppServerAdapter({ manifestPath: fixture.manifestPath, evidenceRoot, runId: () => `allowance-${behavior}`, correlationId: () => `allowance-${behavior}` });
    const result = await adapter.validateAllowance({ path: dirname(fixture.fake.executablePath), allowanceTimeoutMs: 1_000 });
    assert.equal(result.ok, true, result.ok ? "" : result.code); if (!result.ok) return;
    assert.equal(result.providerReadiness, readiness); assert.equal(result.localProjectOSCapability, "available");
    assert.equal(result.buckets[0]?.windowDurationMinutes, 300); assert.equal(result.buckets[0]?.usedPercent, behavior === "success" ? 42 : 100);
    assert.equal(result.remedy?.action ?? null, behavior === "success" ? null : "wait_for_allowance_reset");
    const retained = await readFile(join(evidenceRoot, `allowance-${behavior}-allowance`, "allowance-summary.json"), "utf8");
    assert.doesNotMatch(retained, /secret|token|account|https?:\/\/|\/tmp\//iu);
    const sent = await readFile(fixture.fake.transcriptPath, "utf8"); assert.match(sent, /account\/rateLimits\/read/u); assert.doesNotMatch(sent, /thread\/|turn\/|tool\//u);
  });
}

test("malformed allowance response fails closed without retaining its payload", async () => {
  const fixture = await createFakeRuntimeManifest("allowance-malformed"); const adapter = new CodexAppServerAdapter({ manifestPath: fixture.manifestPath, evidenceRoot: fixture.root });
  const result = await adapter.validateAllowance({ path: dirname(fixture.fake.executablePath), allowanceTimeoutMs: 1_000 });
  assert.equal(result.ok, false); if (!result.ok) assert.equal(result.code, "allowance_malformed");
});
