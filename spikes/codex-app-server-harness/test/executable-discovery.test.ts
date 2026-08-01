import assert from "node:assert/strict";
import { chmod, mkdtemp, mkdir, realpath, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import test from "node:test";

import { discoverCodexExecutable } from "../src/adapters/codex/executable-discovery.ts";
import type { ProviderFailureCode } from "../src/core/failures.ts";

async function fakeExecutable(
  directory: string,
  body = "#!/bin/sh\nprintf 'codex-cli 9.8.7\\n'\n",
): Promise<string> {
  const path = join(directory, "codex");
  await writeFile(path, body, { mode: 0o700 });
  return path;
}

test("discovery honors PATH order, resolves the real path, and captures the exact version", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-discovery-"));
  const first = join(root, "first");
  const second = join(root, "second");
  await mkdir(first);
  await mkdir(second);
  const resolved = await fakeExecutable(second);

  const result = await discoverCodexExecutable({ path: `${first}${delimiter}${second}` });
  assert.deepEqual(result, {
    ok: true,
    candidatePath: resolved,
    executablePath: await realpath(resolved),
    version: "codex-cli 9.8.7",
  });
});

test("discovery rejects executable names that bypass ordered PATH lookup", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-discovery-basename-"));
  const executable = await fakeExecutable(root);
  const result = await discoverCodexExecutable({ path: root, executableName: executable });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "runtime_not_found");
});

test("discovery distinguishes absent, non-executable, broken symlink, and private app bundle candidates", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-discovery-negative-"));
  await assertDiscoveryFailure({ path: root }, "runtime_not_found");

  await writeFile(join(root, "codex"), "not executable", { mode: 0o600 });
  await assertDiscoveryFailure({ path: root }, "runtime_not_executable");

  const broken = join(root, "broken");
  await mkdir(broken);
  await symlink(join(root, "does-not-exist"), join(broken, "codex"));
  await assertDiscoveryFailure({ path: broken }, "runtime_not_found");

  const privateDirectory = join(root, "ChatGPT.app", "Contents", "MacOS");
  await mkdir(privateDirectory, { recursive: true });
  await fakeExecutable(privateDirectory);
  await assertDiscoveryFailure({ path: privateDirectory }, "runtime_not_found");
});

test("version probing rejects timeouts, non-zero exits, and malformed output", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-version-negative-"));
  const timeoutDir = join(root, "timeout");
  const exitDir = join(root, "exit");
  const malformedDir = join(root, "malformed");
  await mkdir(timeoutDir);
  await mkdir(exitDir);
  await mkdir(malformedDir);

  await fakeExecutable(timeoutDir, "#!/bin/sh\nsleep 2\n");
  await assertDiscoveryFailure(
    { path: timeoutDir, versionTimeoutMs: 20 },
    "version_probe_failed",
  );

  await fakeExecutable(exitDir, "#!/bin/sh\nexit 17\n");
  await assertDiscoveryFailure({ path: exitDir }, "version_probe_failed");

  await fakeExecutable(malformedDir, "#!/bin/sh\nprintf 'surprise output\\n'\n");
  await assertDiscoveryFailure({ path: malformedDir }, "version_probe_failed");

  await chmod(join(malformedDir, "codex"), 0o600);
  await assertDiscoveryFailure({ path: malformedDir }, "runtime_not_executable");
});

async function assertDiscoveryFailure(
  options: Parameters<typeof discoverCodexExecutable>[0],
  code: ProviderFailureCode,
): Promise<void> {
  const result = await discoverCodexExecutable(options);
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, code);
}
