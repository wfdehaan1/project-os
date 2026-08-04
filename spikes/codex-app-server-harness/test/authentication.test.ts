import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";

import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import { createFakeRuntimeManifest } from "./fixtures/fake-runtime-manifest.ts";

test("managed ChatGPT authentication uses the compatible owned child and retains no credential values", async () => {
  const fixture = await createFakeRuntimeManifest("success");
  const evidenceRoot = await mkdtemp(join(tmpdir(), "projectos-auth-evidence-"));
  const opened: string[] = [];
  const adapter = new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath, evidenceRoot,
    runId: () => "auth-proof", correlationId: () => "auth-correlation",
    openLoginUrl: (url) => { opened.push(url); },
  });
  const result = await adapter.validateAuthentication({ path: dirname(fixture.fake.executablePath), interactive: true, authenticationTimeoutMs: 1_000 });
  assert.equal(result.ok, true, result.ok ? "" : result.code);
  if (!result.ok) return;
  assert.equal(result.authenticationState, "authenticated_chatgpt");
  assert.equal(result.planCategory, "pro");
  assert.equal(result.expectedPro, "matched");
  assert.equal(result.credentialOwnership, "codex_keyring_only");
  assert.deepEqual(opened, ["https://login.invalid/managed"]);
  const persisted = await readFile(join(evidenceRoot, "auth-proof-authentication", "authentication-summary.json"), "utf8");
  assert.doesNotMatch(persisted, /login\.invalid|account|token|auth\.json|\/tmp\//iu);
  const sent = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.match(sent, /"method":"account\/read"/u);
  assert.match(sent, /"method":"account\/login\/start","params":\{"type":"chatgpt"/u);
  assert.doesNotMatch(sent, /api[_-]?key|authorization|refresh/u);
});

test("non-interactive authentication validation reports signed-out without browser opening", async () => {
  const fixture = await createFakeRuntimeManifest("success");
  const adapter = new CodexAppServerAdapter({ manifestPath: fixture.manifestPath, evidenceRoot: fixture.root, correlationId: () => "auth-signed-out" });
  const result = await adapter.validateAuthentication({ path: dirname(fixture.fake.executablePath), interactive: false, authenticationTimeoutMs: 1_000 });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "authentication_failed");
  const sent = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.doesNotMatch(sent, /account\/login\/start/u);
});

for (const [behavior, expected, failureCode] of [
  ["auth-cancelled", "cancelled", "authentication_cancelled"],
  ["auth-expired", "expired", "authentication_expired"],
  ["auth-failed", "failed", "authentication_failed"],
  ["secure-storage-unavailable", "secure_storage_unavailable", "secure_storage_unavailable"],
] as const) {
  test(`${expected} login outcome is distinct, retryable, and credential-free`, async () => {
    const fixture = await createFakeRuntimeManifest(behavior);
    const adapter = new CodexAppServerAdapter({ manifestPath: fixture.manifestPath, evidenceRoot: fixture.root, runId: () => `auth-${expected}`, correlationId: () => `auth-${expected}` });
    const result = await adapter.validateAuthentication({ path: dirname(fixture.fake.executablePath), interactive: true, authenticationTimeoutMs: 1_000 });
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.code, failureCode);
    const evidence = await readFile(join(fixture.root, `auth-${expected}-authentication`, "authentication-summary.json"), "utf8");
    assert.match(evidence, /"result": "reject"/u);
    assert.match(evidence, /"retryable": true/u);
    const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
    assert.match(transcript, /account\/login\/cancel/u);
    assert.doesNotMatch(transcript, /token|api[_-]?key|authorization/u);
  });
}

test("device-code recovery is unavailable unless the exact generated-and-pinned login schema proves the branch", async () => {
  const fixture = await createFakeRuntimeManifest("success");
  const adapter = new CodexAppServerAdapter({ manifestPath: fixture.manifestPath, evidenceRoot: fixture.root, correlationId: () => "auth-device-absent" });
  const result = await adapter.validateAuthentication({ path: dirname(fixture.fake.executablePath), interactive: true, deviceCodeRecovery: true });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "authentication_unsupported");
  const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.doesNotMatch(transcript, /account\/login\/start/u);
});

test("generated schema-proven device-code recovery is exercised without retaining recovery material", async () => {
  const fixture = await createFakeRuntimeManifest("device-code-supported");
  const evidenceRoot = await mkdtemp(join(tmpdir(), "projectos-device-evidence-"));
  const adapter = new CodexAppServerAdapter({ manifestPath: fixture.manifestPath, evidenceRoot, runId: () => "device-proof", correlationId: () => "auth-device-present" });
  const result = await adapter.validateAuthentication({ path: dirname(fixture.fake.executablePath), interactive: true, deviceCodeRecovery: true, authenticationTimeoutMs: 1_000 });
  assert.equal(result.ok, true, result.ok ? "" : result.code);
  if (!result.ok) return;
  assert.equal(result.deviceCodeCapability, "supported");
  const sent = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.match(sent, /"type":"device_code"/u);
  const evidence = await readFile(join(evidenceRoot, "device-proof-authentication", "authentication-summary.json"), "utf8");
  assert.doesNotMatch(evidence, /device_code|login\.invalid|token|"url"/u);
});

test("an already authenticated disposable profile is rejected without browser proof or logout", async () => {
  const fixture = await createFakeRuntimeManifest("auth-already-authenticated");
  const adapter = new CodexAppServerAdapter({ manifestPath: fixture.manifestPath, evidenceRoot: fixture.root, runId: () => "auth-preexisting", correlationId: () => "auth-preexisting" });
  const result = await adapter.validateAuthentication({ path: dirname(fixture.fake.executablePath), interactive: true, authenticationTimeoutMs: 1_000 });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "authentication_failed");
  const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.doesNotMatch(transcript, /account\/login\/start|account\/logout/u);
  const evidence = await readFile(join(fixture.root, "auth-preexisting-authentication", "authentication-summary.json"), "utf8");
  assert.match(evidence, /"result": "reject"/u);
});

for (const behavior of ["auth-malformed-read", "auth-malformed-login", "auth-malformed-logout"] as const) {
  test(`${behavior} is never treated as a successful authentication result`, async () => {
    const fixture = await createFakeRuntimeManifest(behavior);
    const adapter = new CodexAppServerAdapter({ manifestPath: fixture.manifestPath, evidenceRoot: fixture.root, correlationId: () => behavior });
    const result = await adapter.validateAuthentication({ path: dirname(fixture.fake.executablePath), interactive: true, authenticationTimeoutMs: 1_000 });
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.code, "malformed_handshake_response");
  });
}

test("authentication rejection retains a structural stop-condition record", async () => {
  const fixture = await createFakeRuntimeManifest("reject");
  const evidenceRoot = await mkdtemp(join(tmpdir(), "projectos-auth-reject-evidence-"));
  const adapter = new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    evidenceRoot,
    runId: () => "auth-reject",
    correlationId: () => "auth-reject-correlation",
  });
  const result = await adapter.validateAuthentication({
    path: dirname(fixture.fake.executablePath),
    interactive: true,
    authenticationTimeoutMs: 1_000,
  });
  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.code, "initialization_rejected");
  const persisted = await readFile(join(evidenceRoot, "auth-reject-authentication", "authentication-summary.json"), "utf8");
  assert.match(persisted, /"result": "reject"/u);
  assert.match(persisted, /"failureCode": "initialization_rejected"/u);
  assert.doesNotMatch(persisted, /account|token|auth\.json|\/tmp\//iu);
});
