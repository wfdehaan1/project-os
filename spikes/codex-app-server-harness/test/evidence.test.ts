import assert from "node:assert/strict";
import { chmod, mkdtemp, readFile, readdir, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import type { PrivateRunEvidence } from "../src/evidence/evidence-schema.ts";
import { EvidenceWriteError, writeRunEvidence } from "../src/evidence/evidence-recorder.ts";
import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import { createFakeCodexRuntime } from "./fixtures/fake-codex-runtime.ts";
import { writeAuthenticationEvidence } from "../src/evidence/authentication-evidence-recorder.ts";
import type { AuthenticationValidationEvidence } from "../src/evidence/authentication-evidence-schema.ts";
import { writeAllowanceEvidence } from "../src/evidence/allowance-evidence-recorder.ts";

const secret = "secret-evidence-value-6bfab7";

function evidence(result: "passed" | "failed" = "passed"): PrivateRunEvidence {
  const passed = result === "passed";
  return {
    schemaVersion: 1,
    runId: "run-test-1234",
    correlationId: "corr-test-1234",
    startedAt: "2026-07-31T10:00:00.000Z",
    completedAt: "2026-07-31T10:00:01.000Z",
    harnessVersion: "0.1.0",
    nodeVersion: "v24.18.1",
    runtimeVersion: "codex-cli 9.8.7",
    candidateExecutablePath: "/controlled/private/bin/codex",
    resolvedExecutablePath: "/controlled/private/bin/codex",
    runtimePaths: {
      runtimeRoot: "/controlled/private/run",
      codexHome: "/controlled/private/run/codex-home",
      codexSqliteHome: "/controlled/private/run/codex-sqlite-home",
      disposableHome: "/controlled/private/run/home",
      workingDirectory: "/controlled/private/run/work",
      temporaryDirectory: "/controlled/private/run/tmp",
      configPath: "/controlled/private/run/codex-home/config.toml",
    },
    strictConfigurationFingerprint: "d".repeat(64),
    allowedEnvironmentNames: ["CODEX_HOME", "HOME", "PATH"],
    environmentFingerprints: {
      CODEX_HOME: "a".repeat(64),
      HOME: "b".repeat(64),
      PATH: "c".repeat(64),
    },
    lifecycle: passed
      ? [
          "undiscovered",
          "discovered",
          "starting",
          "initializing",
          "initialized",
          "stopping",
          "stopped",
        ]
      : ["undiscovered", "discovered", "starting", "failed"],
    handshakeOutcome: passed ? "initialized" : "failed",
    shutdownOutcome: passed ? "clean_exit" : "graceful_termination",
    isolationComparison: "unchanged",
    result,
    failureCode: result === "failed" ? "initialization_rejected" : undefined,
    reproductionCommand: "npm ci && npm run validate:full",
  };
}

function authenticationEvidence(runId = "auth-run-1234"): AuthenticationValidationEvidence {
  return {
    schemaVersion: 1,
    runId,
    correlationId: "auth-correlation-1234",
    result: "reject",
    authenticationState: "signed_out",
    planCategory: "unknown",
    expectedPro: "unknown",
    deviceCodeCapability: "unsupported",
    logoutOutcome: "not_needed",
    profileIsolation: "unchanged",
    credentialOwnership: "codex_keyring_only",
    retryable: true,
    failureCode: "authentication_failed",
    reproductionCommand: "PROJECTOS_LIVE_AUTH=1 npm run test:auth:live",
  };
}

test("authentication evidence rejects unsafe run IDs and non-private or symlinked roots", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-auth-evidence-root-"));
  await assert.rejects(
    writeAuthenticationEvidence(authenticationEvidence("../escape"), root),
    /evidence_write_failed/u,
  );
  await writeFile(join(root, "target"), "not a directory", { mode: 0o600 });
  const linkedRoot = join(root, "linked");
  await symlink(join(root, "target"), linkedRoot);
  await assert.rejects(
    writeAuthenticationEvidence(authenticationEvidence(), linkedRoot),
    /evidence_write_failed/u,
  );
  const publicRoot = await mkdtemp(join(tmpdir(), "projectos-auth-evidence-public-"));
  await chmod(publicRoot, 0o755);
  await assert.rejects(
    writeAuthenticationEvidence(authenticationEvidence(), publicRoot),
    /evidence_write_failed/u,
  );
});

test("allowance evidence retains only safe normalized values and rejects canaries", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-allowance-evidence-"));
  const value = { schemaVersion: 1 as const, runId: "allowance-safe", correlationId: "corr-allowance", result: "proceed" as const, runtimeVersion: "codex-cli 9.8.7", providerReadiness: "available" as const, buckets: [{ usedPercent: 20, windowDurationMinutes: 300, resetsAt: null, reachedLimit: false }], remedy: null, failureCode: null, reproductionCommand: "PROJECTOS_LIVE_ALLOWANCE=1 npm run test:allowance:live" as const };
  const path = await writeAllowanceEvidence(value, root); assert.doesNotMatch(await readFile(path, "utf8"), /token|account|https?:\/\/|\/tmp\//iu);
  await assert.rejects(writeAllowanceEvidence({ ...value, runId: "allowance-secret", correlationId: "secret-canary" }, root), /evidence_write_failed/u);
});

test("evidence writes private and sanitized contracts atomically with restricted modes", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-evidence-test-"));
  const result = await writeRunEvidence(evidence(), root);
  assert.equal((await stat(result.runDirectory)).mode & 0o777, 0o700);
  assert.equal((await stat(result.privateEvidencePath)).mode & 0o777, 0o600);
  assert.equal((await stat(result.sanitizedSummaryPath)).mode & 0o777, 0o600);
  assert.deepEqual((await readdir(result.runDirectory)).sort(), ["private.json", "summary.json"]);

  const privateJson = await readFile(result.privateEvidencePath, "utf8");
  const summaryJson = await readFile(result.sanitizedSummaryPath, "utf8");
  assert.match(privateJson, /\/controlled\/private\/bin\/codex/u);
  assert.doesNotMatch(summaryJson, /\/controlled\/private/u);
  assert.doesNotMatch(summaryJson, new RegExp(secret, "u"));
  assert.doesNotMatch(summaryJson, /credential|authorization|account|prompt|rawStderr|rawProtocol/iu);

  const summary = JSON.parse(summaryJson) as Record<string, unknown>;
  const schema = JSON.parse(
    await readFile(new URL("../evidence/harness-run.schema.json", import.meta.url), "utf8"),
  ) as { required: string[] };
  assert.equal(schema.required.every((key) => key in summary), true);
  assert.equal(summary.schemaVersion, 1);
  assert.equal(summary.correlationId, "corr-test-1234");
  assert.equal(summary.executableName, "codex");
  assert.match(String(summary.executableFingerprint), /^[a-f0-9]{64}$/u);
  assert.equal(summary.strictConfigurationFingerprint, "d".repeat(64));
  assert.equal(summary.reproductionCommand, "npm ci && npm run validate:full");
});

test("failed partial evidence remains truthful and complete", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-failed-evidence-"));
  const result = await writeRunEvidence(evidence("failed"), root);
  const summary = JSON.parse(await readFile(result.sanitizedSummaryPath, "utf8")) as {
    result: string;
    failureCode: string;
    handshakeOutcome: string;
  };
  assert.deepEqual(summary, {
    ...summary,
    result: "failed",
    failureCode: "initialization_rejected",
    handshakeOutcome: "failed",
  });
});

test("evidence rejects a passed result without a completed healthy lifecycle", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-invalid-passed-evidence-"));
  await assert.rejects(
    writeRunEvidence({ ...evidence(), handshakeOutcome: "failed" }, root),
    (error: unknown) => error instanceof EvidenceWriteError,
  );
});

test("pre-discovery failure retains a schema-valid partial record without fabricated paths", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-partial-discovery-"));
  let captured: PrivateRunEvidence | undefined;
  const adapter = new CodexAppServerAdapter({
    evidenceRoot: join(root, "evidence"),
    writeEvidence: async (value, evidenceRoot) => {
      captured = value;
      return writeRunEvidence(value, evidenceRoot);
    },
  });
  const result = await adapter.validateRuntime({
    path: join(root, "missing-path"),
  });
  assert.equal(result.ok, false);
  assert.ok(captured);
  assert.equal(captured.runtimeVersion, null);
  assert.equal(captured.candidateExecutablePath, null);
  assert.equal(captured.resolvedExecutablePath, null);
  assert.equal(captured.runtimePaths, null);
  assert.equal(captured.strictConfigurationFingerprint, null);
  assert.equal(captured.result, "failed");
  assert.equal(captured.failureCode, "runtime_not_found");

  const summaryPath = join(root, "evidence", captured.runId, "summary.json");
  const summaryText = await readFile(summaryPath, "utf8");
  assert.doesNotMatch(summaryText, new RegExp(root.replaceAll("/", "\\/"), "u"));
  const summary = JSON.parse(summaryText) as Record<string, unknown>;
  assert.equal(summary.executableName, null);
  assert.equal(summary.executableFingerprint, null);
});

test("profile-creation failures retain an incomplete isolation comparison", async () => {
  let captured: PrivateRunEvidence | undefined;
  const adapter = new CodexAppServerAdapter({
    discover: async () => ({
      ok: true,
      candidatePath: "/controlled/private/bin/codex",
      executablePath: "/controlled/private/bin/codex",
      version: "codex-cli 9.8.7",
    }),
    createProfile: async () => {
      throw new Error("profile creation failed");
    },
    writeEvidence: async (value) => {
      captured = value;
      return {
        runDirectory: "/controlled/private/evidence/run",
        privateEvidencePath: "/controlled/private/evidence/run/private.json",
        sanitizedSummaryPath: "/controlled/private/evidence/run/summary.json",
      };
    },
  });

  const result = await adapter.validateRuntime({});
  assert.equal(result.ok, false);
  assert.ok(captured);
  assert.equal(captured.isolationComparison, "not_completed");
});

test("evidence write failures are terminal and distinctly coded", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-evidence-failure-"));
  const file = join(root, "not-a-directory");
  await writeFile(file, secret, { mode: 0o600 });
  await assert.rejects(
    writeRunEvidence(evidence(), file),
    (error: unknown) =>
      error instanceof EvidenceWriteError && error.code === "evidence_write_failed",
  );
});

test("adapter reports evidence failure only after its owned child is reaped", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-evidence-cleanup-"));
  const fake = await createFakeCodexRuntime(join(root, "fake"), "success");
  const adapter = new CodexAppServerAdapter({
    evidenceRoot: join(root, "evidence"),
    writeEvidence: async () => {
      throw new EvidenceWriteError();
    },
  });
  const result = await adapter.validateRuntime({
    path: join(root, "fake"),
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "evidence_write_failed");
  const pid = Number.parseInt(await readFile(fake.pidPath, "utf8"), 10);
  assert.equal(isAlive(pid), false);
});

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}
