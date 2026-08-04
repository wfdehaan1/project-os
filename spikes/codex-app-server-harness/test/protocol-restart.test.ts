import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname } from "node:path";
import test from "node:test";

import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import { sanitizeProtocolEvidence } from "../src/evidence/protocol-evidence-sanitizer.ts";
import type { ProtocolEvidencePackage } from "../src/evidence/protocol-evidence-schema.ts";
import { createFakeRuntimeManifest } from "./fixtures/fake-runtime-manifest.ts";

const evidenceWriter = async () => ({
  runDirectory: "/private/evidence/run",
  privateEvidencePath: "/private/evidence/run/private.json",
  sanitizedSummaryPath: "/private/evidence/run/summary.json",
});

test("explicit restart discards a failed generation and a fresh second attempt can initialize", async () => {
  const fixture = await createFakeRuntimeManifest("timeout-once");
  let captured: ProtocolEvidencePackage | undefined;
  const result = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: async (...arguments_) => {
      captured = arguments_[2];
      return evidenceWriter();
    },
  }).validateRuntime({
    path: dirname(fixture.fake.executablePath),
    initializationTimeoutMs: 300,
    shutdownTimeoutMs: 100,
    restart: true,
  });
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.ok(captured);
  assert.equal(result.attemptCount, 2);
  assert.equal(captured?.privateEvidence.attempts.length, 2);
  assert.equal(
    captured?.privateEvidence.reproductionCommand,
    "npm ci && npm run protocol:validate -- --restart",
  );
  assert.equal(
    sanitizeProtocolEvidence(captured.privateEvidence).reproductionCommand,
    "npm ci && npm run protocol:validate -- --restart",
  );
  const [firstAttempt, secondAttempt] = captured?.privateEvidence.attempts ?? [];
  assert.notEqual(firstAttempt?.correlationId, secondAttempt?.correlationId);
  assert.equal(firstAttempt?.failureCode, "initialization_timeout");
  assert.equal(secondAttempt?.failureCode, null);
  const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.equal(transcript.match(/"app-server","--stdio","--strict-config"/gu)?.length, 2);
});

test("without an explicit restart the same first failure remains terminal", async () => {
  const fixture = await createFakeRuntimeManifest("timeout-once");
  const result = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: evidenceWriter,
  }).validateRuntime({
    path: dirname(fixture.fake.executablePath),
    initializationTimeoutMs: 300,
    shutdownTimeoutMs: 100,
  });
  assert.equal(result.ok, false);
  const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.equal(transcript.match(/"app-server","--stdio","--strict-config"/gu)?.length, 1);
});

test("a failed second generation is normalized as restart_failed", async () => {
  const fixture = await createFakeRuntimeManifest("malformed");
  let captured: ProtocolEvidencePackage | undefined;
  const result = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: async (...arguments_) => {
      captured = arguments_[2];
      return evidenceWriter();
    },
  }).validateRuntime({
    path: dirname(fixture.fake.executablePath),
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 50,
    restart: true,
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "restart_failed");
  assert.ok(captured);
  const attempts = captured?.privateEvidence.attempts ?? [];
  assert.equal(attempts[1]?.failureCode, "restart_failed");
  assert.equal(attempts[1]?.underlyingFailureCode, "malformed_handshake_response");
  assert.equal(
    captured?.privateEvidence.reproductionCommand,
    "npm ci && npm run protocol:validate -- --restart",
  );
  assert.equal(
    sanitizeProtocolEvidence(captured.privateEvidence).failureCode,
    "restart_failed",
  );
  assert.notEqual(attempts[0]?.correlationId, attempts[1]?.correlationId);
  const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.equal(transcript.match(/"app-server","--stdio","--strict-config"/gu)?.length, 2);
});

test("late output from the reaped old process group cannot initialize the fresh attempt", async () => {
  const fixture = await createFakeRuntimeManifest("late-old-message");
  let captured: ProtocolEvidencePackage | undefined;
  const result = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: async (...arguments_) => {
      captured = arguments_[2];
      return evidenceWriter();
    },
  }).validateRuntime({
    path: dirname(fixture.fake.executablePath),
    initializationTimeoutMs: 250,
    shutdownTimeoutMs: 100,
    restart: true,
  });
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.attemptCount, 2);
  assert.ok(captured);
  const [oldGeneration, freshGeneration] = captured.privateEvidence.attempts;
  assert.equal(oldGeneration?.failureCode, "initialization_timeout");
  assert.equal(oldGeneration?.processOwnership?.reaped, true);
  assert.equal(oldGeneration?.transcript.some((entry) => entry.classification === "matched"), false);
  assert.equal(freshGeneration?.failureCode, null);
  assert.equal(freshGeneration?.transcript.some((entry) => entry.classification === "matched"), true);
  assert.notEqual(oldGeneration?.attemptId, freshGeneration?.attemptId);
  assert.notEqual(oldGeneration?.correlationId, freshGeneration?.correlationId);
  const oldDescendantPid = Number.parseInt(
    await readFile(fixture.fake.descendantPidPath, "utf8"),
    10,
  );
  assert.equal(await stopsWithin(oldDescendantPid, 500), true);
  const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.equal(transcript.match(/"app-server","--stdio","--strict-config"/gu)?.length, 2);
  assert.equal(
    captured.privateEvidence.attempts.flatMap((attempt) => attempt.transcript)
      .some((entry) => entry.method === "late-old"),
    false,
  );
});

function isAlive(pid: number): boolean {
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
