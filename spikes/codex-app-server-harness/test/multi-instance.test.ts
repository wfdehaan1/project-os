import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, readFile, readdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";

import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import {
  createIsolatedRuntimeProfile,
  type IsolatedRuntimeProfile,
  type RuntimeProfileOptions,
} from "../src/adapters/codex/runtime-profile.ts";
import type { PrivateRunEvidence } from "../src/evidence/evidence-schema.ts";
import type { PrivateProtocolValidationEvidence } from "../src/evidence/protocol-evidence-schema.ts";
import { createFakeRuntimeManifest } from "./fixtures/fake-runtime-manifest.ts";
import type { FakeCodexBehavior } from "./fixtures/fake-codex-runtime.ts";

test("two concurrent instances sharing one runtime keep profiles, evidence, sessions, and ownership separate", async (t) => {
  const fixture = await createFakeRuntimeManifest("success");
  const evidenceRoot = join(fixture.root, "evidence");
  const sentinel = ownedSentinel(t);
  const [alphaResult, betaResult] = await Promise.all([
    adapter(fixture, evidenceRoot, "run-alpha", "corr-alpha", "account-alpha/session-alpha", "success")
      .validateRuntime({ path: dirname(fixture.fake.executablePath), initializationTimeoutMs: 750, shutdownTimeoutMs: 100 }),
    adapter(fixture, evidenceRoot, "run-beta", "corr-beta", "account-beta/session-beta", "success")
      .validateRuntime({ path: dirname(fixture.fake.executablePath), initializationTimeoutMs: 750, shutdownTimeoutMs: 100 }),
  ]);
  assert.equal(alphaResult.ok, true);
  assert.equal(betaResult.ok, true);
  assert.equal(isAlive(sentinel.pid), true);

  const alpha = await evidence(evidenceRoot, "run-alpha");
  const beta = await evidence(evidenceRoot, "run-beta");
  assertIndependentEvidence(alpha, beta);
  assert.equal(alpha.base.isolationComparison, "unchanged");
  assert.equal(beta.base.isolationComparison, "unchanged");
  assert.equal(alpha.protocol.result, "passed");
  assert.equal(beta.protocol.result, "passed");
  assert.deepEqual((await readdir(alpha.runDirectory)).sort(), expectedEvidenceFiles);
  assert.deepEqual((await readdir(beta.runDirectory)).sort(), expectedEvidenceFiles);

  const records = await transcriptRecords(fixture.fake.transcriptPath);
  assertMarkerIsolation(records, "account-alpha/session-alpha", "account-beta/session-beta");
  await assertOwnedAttemptsReaped(alpha.protocol, beta.protocol);
});

test("forced termination in one shared-runtime instance cannot stop or contaminate its neighbor", async (t) => {
  const fixture = await createFakeRuntimeManifest("success");
  const evidenceRoot = join(fixture.root, "evidence");
  const sentinel = ownedSentinel(t);
  const [healthyResult, forcedResult] = await Promise.all([
    adapter(fixture, evidenceRoot, "run-healthy", "corr-healthy", "healthy-instance", "success")
      .validateRuntime({ path: dirname(fixture.fake.executablePath), initializationTimeoutMs: 750, shutdownTimeoutMs: 100 }),
    adapter(fixture, evidenceRoot, "run-forced", "corr-forced", "forced-instance", "ignore-term")
      .validateRuntime({ path: dirname(fixture.fake.executablePath), initializationTimeoutMs: 250, shutdownTimeoutMs: 50 }),
  ]);
  assert.equal(healthyResult.ok, true);
  assert.equal(forcedResult.ok, false);
  if (!forcedResult.ok) assert.equal(forcedResult.code, "initialization_timeout");
  assert.equal(isAlive(sentinel.pid), true);

  const healthy = await evidence(evidenceRoot, "run-healthy");
  const forced = await evidence(evidenceRoot, "run-forced");
  assertIndependentEvidence(healthy, forced);
  assert.equal(healthy.base.isolationComparison, "unchanged");
  assert.equal(forced.base.isolationComparison, "unchanged");
  assert.equal(healthy.protocol.result, "passed");
  assert.equal(forced.protocol.result, "failed");
  assert.equal(forced.protocol.failureCode, "initialization_timeout");
  assert.equal(forced.protocol.attempts[0]?.shutdownOutcome, "forced_termination");

  const records = await transcriptRecords(fixture.fake.transcriptPath);
  assertMarkerIsolation(records, "healthy-instance", "forced-instance");
  await assertOwnedAttemptsReaped(healthy.protocol, forced.protocol);
});

const expectedEvidenceFiles = [
  "private.json",
  "protocol-private.json",
  "protocol-schemas",
  "protocol-summary.json",
  "protocol-transcript.json",
  "summary.json",
];

function adapter(
  fixture: Awaited<ReturnType<typeof createFakeRuntimeManifest>>,
  evidenceRoot: string,
  runId: string,
  correlationId: string,
  marker: string,
  behavior: FakeCodexBehavior,
): CodexAppServerAdapter {
  return new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    evidenceRoot,
    runId: () => runId,
    correlationId: () => correlationId,
    createProfile: markedProfile(join(fixture.root, `profiles-${runId}`), marker, behavior),
  });
}

function markedProfile(
  baseDirectory: string,
  marker: string,
  behavior: FakeCodexBehavior,
): (options?: RuntimeProfileOptions) => Promise<IsolatedRuntimeProfile> {
  return async (options = {}) => {
    const profile = await createIsolatedRuntimeProfile({ ...options, baseDirectory });
    await Promise.all([
      writeFile(join(profile.codexHome, "synthetic-marker.txt"), `${marker}\n`, { mode: 0o600 }),
      writeFile(join(profile.codexHome, "synthetic-behavior.txt"), `${behavior}\n`, { mode: 0o600 }),
    ]);
    return profile;
  };
}

async function evidence(root: string, runId: string): Promise<{
  runDirectory: string;
  base: PrivateRunEvidence;
  protocol: PrivateProtocolValidationEvidence;
}> {
  const runDirectory = join(root, runId);
  return {
    runDirectory,
    base: JSON.parse(await readFile(join(runDirectory, "private.json"), "utf8")) as PrivateRunEvidence,
    protocol: JSON.parse(
      await readFile(join(runDirectory, "protocol-private.json"), "utf8"),
    ) as PrivateProtocolValidationEvidence,
  };
}

function assertIndependentEvidence(
  left: Awaited<ReturnType<typeof evidence>>,
  right: Awaited<ReturnType<typeof evidence>>,
): void {
  assert.notEqual(left.runDirectory, right.runDirectory);
  assert.notEqual(left.base.runId, right.base.runId);
  assert.notEqual(left.base.correlationId, right.base.correlationId);
  assert.notEqual(left.base.runtimePaths?.runtimeRoot, right.base.runtimePaths?.runtimeRoot);
  assert.notEqual(left.base.runtimePaths?.codexHome, right.base.runtimePaths?.codexHome);
  assert.notEqual(
    left.base.environmentFingerprints.CODEX_HOME,
    right.base.environmentFingerprints.CODEX_HOME,
  );
  assert.equal(left.base.strictConfigurationFingerprint, right.base.strictConfigurationFingerprint);
  assert.notEqual(left.protocol.attempts[0]?.attemptId, right.protocol.attempts[0]?.attemptId);
  assert.notEqual(left.protocol.attempts[0]?.correlationId, right.protocol.attempts[0]?.correlationId);
}

async function transcriptRecords(path: string): Promise<Array<Record<string, unknown>>> {
  return (await readFile(path, "utf8"))
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line) as Record<string, unknown>);
}

function assertMarkerIsolation(
  records: readonly Record<string, unknown>[],
  leftMarker: string,
  rightMarker: string,
): void {
  const left = records.filter((record) => record.marker === leftMarker);
  const right = records.filter((record) => record.marker === rightMarker);
  assert.equal(left.length > 0, true);
  assert.equal(right.length > 0, true);
  assert.equal(left.every((record) => record.syntheticSession === leftMarker), true);
  assert.equal(right.every((record) => record.syntheticSession === rightMarker), true);
  assert.equal(left.some((record) => record.syntheticSession === rightMarker), false);
  assert.equal(right.some((record) => record.syntheticSession === leftMarker), false);
  assert.equal(
    new Set(left.map((record) => record.codexHome)).intersection(
      new Set(right.map((record) => record.codexHome)),
    ).size,
    0,
  );
  assert.equal(
    [...left, ...right].some((record) =>
      JSON.stringify(record).match(/account\/read|thread\/start/iu)),
    false,
  );
}

async function assertOwnedAttemptsReaped(
  ...protocolEvidence: readonly PrivateProtocolValidationEvidence[]
): Promise<void> {
  const attempts = protocolEvidence.flatMap((protocol) => protocol.attempts);
  const pids = attempts.map((attempt) => attempt.processOwnership?.childPid).filter(isNumber);
  assert.equal(new Set(pids).size, pids.length);
  assert.equal(attempts.every((attempt) => attempt.processOwnership?.reaped === true), true);
  for (const pid of pids) assert.equal(await stopsWithin(pid, 500), true);
}

function ownedSentinel(t: test.TestContext) {
  const sentinel = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
    detached: process.platform !== "win32",
    stdio: "ignore",
  });
  t.after(() => {
    if (!sentinel.pid || !isAlive(sentinel.pid)) return;
    if (process.platform === "win32") sentinel.kill("SIGKILL");
    else process.kill(-sentinel.pid, "SIGKILL");
  });
  return sentinel;
}

function isNumber(value: number | null | undefined): value is number {
  return typeof value === "number";
}

function isAlive(pid: number | undefined): boolean {
  if (!pid) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function stopsWithin(pid: number, timeoutMs: number): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (isAlive(pid) && Date.now() < deadline) {
    await new Promise((resolveWait) => setTimeout(resolveWait, 10));
  }
  return !isAlive(pid);
}
