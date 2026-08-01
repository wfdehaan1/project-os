import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { superviseCodexAppServer } from "../src/adapters/codex/app-server-supervisor.ts";
import { createFakeCodexRuntime } from "./fixtures/fake-codex-runtime.ts";

test("supervisor uses strict stdio args and initialize then initialized JSONL order", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-handshake-"));
  const fake = await createFakeCodexRuntime(root, "success");
  const result = await superviseCodexAppServer({
    executablePath: fake.executablePath,
    workingDirectory: root,
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 500,
    correlationId: "corr-handshake",
  });
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.shutdownOutcome, "clean_exit");
  assert.deepEqual(result.lifecycle, [
    "undiscovered",
    "discovered",
    "starting",
    "initializing",
    "initialized",
    "stopping",
    "stopped",
  ]);

  const lines = (await readFile(fake.transcriptPath, "utf8"))
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line) as Record<string, unknown>);
  assert.deepEqual(lines[0], { argv: ["app-server", "--stdio", "--strict-config"] });
  assert.deepEqual(lines[1], {
    id: 1,
    method: "initialize",
    params: {
      clientInfo: { name: "ProjectOS", title: "ProjectOS validation harness", version: "0.1.0" },
      capabilities: { experimentalApi: false },
    },
  });
  assert.deepEqual(lines[2], { method: "initialized" });
});

test("supervisor ignores an unrelated response ID and waits for the matching response", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-matching-id-"));
  const fake = await createFakeCodexRuntime(root, "wrong-id-then-match");
  const result = await superviseCodexAppServer({
    executablePath: fake.executablePath,
    workingDirectory: root,
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
    correlationId: "corr-matching-id",
  });
  assert.equal(result.ok, true);
});

test("supervisor rejects duplicate matching initialize responses without sending initialized twice", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-duplicate-match-"));
  const fake = await createFakeCodexRuntime(root, "duplicate-match");
  const result = await superviseCodexAppServer({
    executablePath: fake.executablePath,
    workingDirectory: root,
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
    correlationId: "corr-duplicate-match",
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "malformed_handshake_response");

  const initializedCount = (await readFile(fake.transcriptPath, "utf8"))
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line) as Record<string, unknown>)
    .filter((line) => line.method === "initialized").length;
  assert.equal(initializedCount, 1);
});

for (const [behavior, code] of [
  ["reject", "initialization_rejected"],
  ["malformed", "malformed_handshake_response"],
  ["eof", "unexpected_exit_or_eof"],
  ["timeout", "initialization_timeout"],
  ["unexpected-exit", "unexpected_exit_or_eof"],
] as const) {
  test(`supervisor maps ${behavior} without starting provider work`, async () => {
    const root = await mkdtemp(join(tmpdir(), `projectos-${behavior}-`));
    const fake = await createFakeCodexRuntime(root, behavior);
    const result = await superviseCodexAppServer({
      executablePath: fake.executablePath,
      workingDirectory: root,
      environment: { PATH: "/usr/bin:/bin" },
      initializationTimeoutMs: 500,
      shutdownTimeoutMs: 30,
      correlationId: `corr-${behavior}`,
    });
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.code, code);
    assert.equal(result.providerActionEnabled, false);
    assert.equal(result.canonicalStateOperationEnabled, false);
    const pid = Number.parseInt(await readFile(fake.pidPath, "utf8"), 10);
    assert.equal(isAlive(pid), false);
    if (behavior === "timeout") assert.equal(result.shutdownOutcome, "graceful_termination");
    if (behavior === "malformed") assert.equal(result.shutdownOutcome, "graceful_termination");
  });
}

test("spawn failure is distinct", async () => {
  const result = await superviseCodexAppServer({
    executablePath: "/definitely/not/a/projectos-runtime",
    workingDirectory: tmpdir(),
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 30,
    shutdownTimeoutMs: 30,
    correlationId: "corr-spawn",
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "spawn_failed");
});

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}
