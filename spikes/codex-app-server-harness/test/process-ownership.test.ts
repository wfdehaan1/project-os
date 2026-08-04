import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";
import test from "node:test";

import { superviseCodexAppServer } from "../src/adapters/codex/app-server-supervisor.ts";
import { createFakeCodexRuntime } from "./fixtures/fake-codex-runtime.ts";
import { fakeCompatibilityCapability } from "./fixtures/fake-compatibility-capability.ts";

test("forced cleanup reaps only the recorded process group", async (t) => {
  const root = await mkdtemp(join(tmpdir(), "projectos-owned-process-"));
  const fake = await createFakeCodexRuntime(root, "ignore-term");
  const unrelated = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
    detached: true,
    stdio: "ignore",
  });
  t.after(() => {
    if (unrelated.pid) process.kill(-unrelated.pid, "SIGKILL");
  });

  const result = await superviseCodexAppServer({
    ...(await fakeCompatibilityCapability(fake, root, "attempt-owned")),
    initializationTimeoutMs: 300,
    shutdownTimeoutMs: 50,
    correlationId: "corr-owned",
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.shutdownOutcome, "forced_termination");
    assert.equal(result.processGroupReaped, true);
    assert.equal(result.processGroupId, result.childPid);
  }
  const ownedPid = Number.parseInt(await readFile(fake.pidPath, "utf8"), 10);
  assert.equal(await stopsWithin(ownedPid, 500), true);
  assert.equal(isAlive(unrelated.pid), true);
});

test("post-handshake assertion failure still reaps the owned child", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-assertion-process-"));
  const fake = await createFakeCodexRuntime(root, "success");
  const result = await superviseCodexAppServer({
    ...(await fakeCompatibilityCapability(fake, root, "attempt-assertion")),
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
    correlationId: "corr-assertion",
    postInitializeCheck: () => {
      throw new Error("synthetic assertion");
    },
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "isolation_failed");
  const pid = Number.parseInt(await readFile(fake.pidPath, "utf8"), 10);
  assert.equal(isAlive(pid), false);
});

test("clean leader exit still reaps descendants in the owned process group", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-clean-leader-process-"));
  const fake = await createFakeCodexRuntime(root, "leader-exits-child-runs");
  const result = await superviseCodexAppServer({
    ...(await fakeCompatibilityCapability(fake, root, "attempt-clean-leader")),
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 50,
    correlationId: "corr-clean-leader",
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.equal(result.processGroupReaped, true);
    assert.equal(result.processGroupId, result.childPid);
  }
  const descendantPid = Number.parseInt(await readFile(fake.descendantPidPath, "utf8"), 10);
  assert.equal(await stopsWithin(descendantPid, 500), true);
});

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
