import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { spawn } from "node:child_process";
import test from "node:test";

import {
  assertFixtureUnchanged,
  auditProjectOSProfileCredentialOwnership,
  createIsolatedRuntimeProfile,
  createSyntheticNormalProfileFixture,
  snapshotFixture,
} from "../src/adapters/codex/runtime-profile.ts";

test("runtime profile creates unique restricted paths and strict configuration", async () => {
  const base = await mkdtemp(join(tmpdir(), "projectos-runtime-test-"));
  const first = await createIsolatedRuntimeProfile({ baseDirectory: base });
  const second = await createIsolatedRuntimeProfile({ baseDirectory: base });
  assert.notEqual(first.runtimeRoot, second.runtimeRoot);

  for (const path of [
    first.runtimeRoot,
    first.codexHome,
    first.codexSqliteHome,
    first.disposableHome,
    first.workingDirectory,
    first.temporaryDirectory,
  ]) {
    assert.equal((await stat(path)).mode & 0o777, 0o700, path);
  }
  assert.equal((await stat(first.configPath)).mode & 0o777, 0o600);
  assert.equal(
    await readFile(first.configPath, "utf8"),
    'forced_login_method = "chatgpt"\ncli_auth_credentials_store = "keyring"\n[analytics]\nenabled = false\n',
  );
  assert.match(first.strictConfigurationFingerprint, /^[a-f0-9]{64}$/u);
  assert.equal(first.childEnvironment.PATH?.split(":")[0], dirname(process.execPath));
});

test("credential ownership audit fails closed for unexpected profile files without reading them", async () => {
  const base = await mkdtemp(join(tmpdir(), "projectos-credential-audit-"));
  const profile = await createIsolatedRuntimeProfile({ baseDirectory: base });
  await assert.doesNotReject(auditProjectOSProfileCredentialOwnership(profile));
  const canary = "uninspected-plaintext-token-4da3";
  await writeFile(join(profile.disposableHome, "ordinary-notes.txt"), canary, { mode: 0o600 });
  await assert.rejects(auditProjectOSProfileCredentialOwnership(profile), /isolation_failed/u);
});

test("child environment is exact, scrubbed, and fingerprints values without exposing them", async () => {
  const base = await mkdtemp(join(tmpdir(), "projectos-environment-test-"));
  const secret = "must-not-leak-8c07458f";
  const profile = await createIsolatedRuntimeProfile({
    baseDirectory: base,
    parentEnvironment: {
      PATH: "/attacker/bin",
      OPENAI_API_KEY: secret,
      GH_TOKEN: secret,
      SSH_AUTH_SOCK: secret,
      HTTPS_PROXY: secret,
      MCP_CONFIG: secret,
      CODEX_HOME: "/real/profile",
    },
    minimalPath: "/usr/bin:/bin",
    certificateConfiguration: { sslCertFile: "/controlled/certificate.pem" },
  });

  assert.deepEqual(Object.keys(profile.childEnvironment).sort(), [
    "CODEX_HOME",
    "CODEX_SQLITE_HOME",
    "HOME",
    "LANG",
    "LC_ALL",
    "PATH",
    "SSL_CERT_FILE",
    "TMPDIR",
  ]);
  assert.equal(profile.childEnvironment.PATH, "/usr/bin:/bin");
  assert.equal(profile.childEnvironment.SSL_CERT_FILE, "/controlled/certificate.pem");
  assert.equal(JSON.stringify(profile.childEnvironment).includes(secret), false);
  assert.deepEqual(profile.allowedEnvironmentNames, Object.keys(profile.childEnvironment).sort());
  assert.equal(JSON.stringify(profile.environmentFingerprints).includes(secret), false);
  assert.equal(Object.values(profile.environmentFingerprints).every((value) => /^[a-f0-9]{64}$/u.test(value)), true);
});

test("synthetic normal profile and unrelated process remain unchanged", async (t) => {
  const base = await mkdtemp(join(tmpdir(), "projectos-normal-profile-test-"));
  const fixture = await createSyntheticNormalProfileFixture(join(base, "normal"));
  const before = await snapshotFixture(fixture);
  const sentinel = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
    stdio: "ignore",
  });
  t.after(() => sentinel.kill("SIGKILL"));

  await createIsolatedRuntimeProfile({
    baseDirectory: join(base, "runs"),
    normalProfileRoot: fixture,
  });

  await assertFixtureUnchanged(before, await snapshotFixture(fixture));
  assert.equal(sentinel.exitCode, null);
  assert.equal(sentinel.killed, false);
});

test("runtime profile rejects symlink roots and real-profile fallback", async () => {
  const base = await mkdtemp(join(tmpdir(), "projectos-runtime-reject-"));
  const target = join(base, "target");
  const linked = join(base, "linked");
  await mkdir(target);
  await symlink(target, linked);

  await assert.rejects(
    createIsolatedRuntimeProfile({ baseDirectory: linked }),
    /isolation_failed/u,
  );
  await assert.rejects(
    createIsolatedRuntimeProfile({ baseDirectory: target, realHome: target }),
    /isolation_failed/u,
  );
});

test("normal-profile snapshots include empty directories", async () => {
  const base = await mkdtemp(join(tmpdir(), "projectos-normal-directory-snapshot-"));
  const fixture = await createSyntheticNormalProfileFixture(join(base, "normal"));
  const before = await snapshotFixture(fixture);
  await mkdir(join(fixture, "unexpected-empty-directory"));

  await assert.rejects(
    assertFixtureUnchanged(before, await snapshotFixture(fixture)),
    /isolation_failed/u,
  );
});
