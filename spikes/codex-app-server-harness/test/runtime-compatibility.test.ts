import assert from "node:assert/strict";
import { lstat, mkdtemp, readFile, readdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";

import { createExecutableSnapshot } from "../src/adapters/codex/executable-snapshot.ts";
import {
  PROTOCOL_DIGEST_ALGORITHM,
  extractGeneratedProtocolMethods,
  schemaTreeAggregateBytes,
  sha256,
  type SupportedRuntimeManifest,
} from "../src/adapters/codex/protocol-contract.ts";
import { generateProtocolSchemas } from "../src/adapters/codex/protocol-schema-generator.ts";
import { validateSnapshotCompatibility } from "../src/adapters/codex/runtime-compatibility.ts";
import { createIsolatedRuntimeProfile } from "../src/adapters/codex/runtime-profile.ts";
import {
  createFakeCodexRuntime,
  type FakeCodexBehavior,
} from "./fixtures/fake-codex-runtime.ts";
import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import { sanitizeProtocolEvidence } from "../src/evidence/protocol-evidence-sanitizer.ts";
import type { ProtocolEvidencePackage } from "../src/evidence/protocol-evidence-schema.ts";
import type { PrivateRunEvidence } from "../src/evidence/evidence-schema.ts";

test("snapshot compatibility probes, generates, compares, and mints one attempt capability", async () => {
  const fixture = await compatibilityFixture();
  const result = await validateFixture(fixture, "attempt-compatible", "validation-generated");
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.detectedBuild, "codex-cli 9.8.7");
  assert.equal(result.manifest.manifestId, "test-runtime-manifest");
  assert.match(result.manifestDigest, /^[a-f0-9]{64}$/u);
});

test("unsupported build fails before schema generation", async () => {
  const fixture = await compatibilityFixture({ manifestBuild: "codex-cli 0.0.0" });
  const result = await validateFixture(fixture, "attempt-build-mismatch", "must-not-generate");
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.reason, "unsupported_build");
    assert.equal(result.detectedBuild, "codex-cli 9.8.7");
    assert.equal(result.supportedBuild, "codex-cli 0.0.0");
    assert.equal(result.manifest?.manifestId, "test-runtime-manifest");
    assert.match(result.manifestDigest ?? "", /^[a-f0-9]{64}$/u);
    assert.equal(result.generationAttempted, undefined);
  }
  const commands = (await readFile(fixture.fake.transcriptPath, "utf8")).trim().split("\n");
  assert.equal(commands.filter((line) => line.includes("generate-")).length, 2);
});

test("same-build schema and required-method drift fail closed", async () => {
  const schemaDrift = await compatibilityFixture({ tamperJsonDigest: true });
  const driftResult = await validateFixture(schemaDrift, "attempt-schema-drift", "drift-generated");
  assert.equal(driftResult.ok, false);
  if (!driftResult.ok) assert.equal(driftResult.reason, "schema_mismatch");

  const methodDrift = await compatibilityFixture({ addMissingRequiredMethod: true });
  const methodResult = await validateFixture(methodDrift, "attempt-method-drift", "method-generated");
  assert.equal(methodResult.ok, false);
  if (!methodResult.ok) assert.equal(methodResult.reason, "missing_required_method");
});

for (const [behavior, expectedReason] of [
  ["schema-drift", "schema_mismatch"],
  ["experimental-output", "schema_mismatch"],
  ["generator-crash", "runtime_terminated"],
  ["generator-timeout", "schema_generation_failed"],
  ["generator-nonzero", "schema_generation_failed"],
  ["generator-malformed", "schema_generation_failed"],
  ["generator-missing", "schema_generation_failed"],
  ["generator-extra", "schema_mismatch"],
  ["generator-oversized", "schema_generation_failed"],
] as const) {
  test(`fake runtime ${behavior} is bounded and fails closed`, async () => {
    const fixture = await compatibilityFixture({ afterManifestBehavior: behavior });
    const result = await validateFixture(fixture, `attempt-${behavior}`, `generated-${behavior}`);
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.reason, expectedReason);
      assert.equal(result.generationAttempted, true);
    }
  });
}

test("authoritative version probe reaps descendants before compatibility succeeds", async () => {
  const fixture = await compatibilityFixture({
    afterManifestBehavior: "version-leader-exits-child-runs",
  });
  const result = await validateFixture(fixture, "attempt-version-descendant", "version-descendant");
  assert.equal(result.ok, true);
  const descendantPid = Number.parseInt(await readFile(fixture.fake.descendantPidPath, "utf8"), 10);
  assert.equal(await stopsWithin(descendantPid, 500), true);
});

test("snapshot compatibility rejects structurally forged snapshot objects", async () => {
  const fixture = await compatibilityFixture();
  await assert.rejects(
    validateSnapshotCompatibility({
      attemptId: "attempt-forged-snapshot",
      snapshot: { ...fixture.snapshot } as never,
      manifestPath: fixture.manifestPath,
      environment: fixture.profile.childEnvironment,
      workingDirectory: fixture.profile.workingDirectory,
      stagingDirectory: join(fixture.profile.runtimeRoot, "forged-snapshot-generated"),
      versionTimeoutMs: 500,
      generatorTimeoutMs: 500,
      generatorShutdownStepMs: 50,
    }),
    /runtime_snapshot_failed/u,
  );
});

test("adapter runs App Server only after exact compatibility and returns provider-neutral metadata", async () => {
  const fixture = await compatibilityFixture();
  let capturedProtocol: ProtocolEvidencePackage | undefined;
  const adapter = new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: async (_evidence, _root, protocol) => {
      capturedProtocol = protocol;
      return {
      runDirectory: "/private/evidence/run",
      privateEvidencePath: "/private/evidence/run/private.json",
      sanitizedSummaryPath: "/private/evidence/run/summary.json",
      };
    },
  });
  const result = await adapter.validateRuntime({
    path: dirname(fixture.fake.executablePath),
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
  });
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.compatibilityStatus, "compatible");
  assert.equal(result.manifestId, "test-runtime-manifest");
  assert.match(result.schemaDigests.jsonSha256, /^[a-f0-9]{64}$/u);
  assert.equal(result.providerActionEnabled, false);
  assert.equal(result.canonicalStateOperationEnabled, false);
  assert.ok(capturedProtocol);
  assert.equal(capturedProtocol.privateEvidence.attempts[0]?.compatibilityOutcome, "compatible");
  assert.equal(capturedProtocol.privateEvidence.attempts[0]?.manifest?.manifestId, "test-runtime-manifest");
  assert.equal(capturedProtocol.privateEvidence.attempts[0]?.processOwnership?.reaped, true);
  assert.ok(capturedProtocol.privateEvidence.attempts[0]?.processOwnership?.childPid);
  assert.equal(capturedProtocol.attachments.length, 2);
  const shareable = JSON.stringify(sanitizeProtocolEvidence(capturedProtocol.privateEvidence));
  assert.doesNotMatch(shareable, new RegExp(fixture.profile.runtimeRoot.replaceAll("/", "\\/"), "u"));
  assert.doesNotMatch(shareable, /snapshotExecutablePath|exactJsonArgv|exactTypescriptArgv/iu);
  const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.equal(transcript.includes('"app-server","--stdio","--strict-config"'), true);
});

test("preliminary discovery version is never retained as authoritative compatibility evidence", async () => {
  const fixture = await compatibilityFixture();
  await writeFile(fixture.manifestPath, "{}\n", { mode: 0o600 });
  let capturedBase: PrivateRunEvidence | undefined;
  let capturedProtocol: ProtocolEvidencePackage | undefined;
  const result = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: async (base, _root, protocol) => {
      capturedBase = base;
      capturedProtocol = protocol;
      return {
        runDirectory: "/private/evidence/run",
        privateEvidencePath: "/private/evidence/run/private.json",
        sanitizedSummaryPath: "/private/evidence/run/summary.json",
      };
    },
  }).validateRuntime({ path: dirname(fixture.fake.executablePath) });

  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "invalid_protocol_manifest");
  assert.equal(capturedBase?.runtimeVersion, null);
  assert.equal(capturedProtocol?.privateEvidence.attempts[0]?.detectedBuild, null);
});

test("adapter build mismatch is sanitized and never spawns App Server", async () => {
  const fixture = await compatibilityFixture({ manifestBuild: "codex-cli 0.0.0" });
  let capturedProtocol: ProtocolEvidencePackage | undefined;
  const adapter = new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: async (_evidence, _root, protocol) => {
      capturedProtocol = protocol;
      return {
      runDirectory: "/private/evidence/run",
      privateEvidencePath: "/private/evidence/run/private.json",
      sanitizedSummaryPath: "/private/evidence/run/summary.json",
      };
    },
  });
  const result = await adapter.validateRuntime({ path: dirname(fixture.fake.executablePath) });
  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.code, "unsupported_runtime_build");
  assert.equal(result.detectedBuild, "codex-cli 9.8.7");
  assert.equal(result.supportedBuild, "codex-cli 0.0.0");
  assert.equal(JSON.stringify(result).includes(fixture.fake.executablePath), false);
  assert.ok(capturedProtocol);
  assert.equal(capturedProtocol.privateEvidence.failureCode, "unsupported_runtime_build");
  assert.equal(capturedProtocol.privateEvidence.attempts[0]?.compatibilityOutcome, "incompatible");
  assert.equal(capturedProtocol.privateEvidence.attempts[0]?.exactJsonArgv, null);
  assert.equal(capturedProtocol.attachments.length, 0);
  const transcript = await readFile(fixture.fake.transcriptPath, "utf8");
  assert.equal(transcript.includes('"app-server","--stdio","--strict-config"'), false);
});

test("adapter atomically records private schemas and a path-free companion protocol summary", async () => {
  const fixture = await compatibilityFixture();
  const evidenceRoot = join(dirname(fixture.manifestPath), "evidence");
  const adapter = new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    evidenceRoot,
    runId: () => "run-integrated-protocol-evidence",
    correlationId: () => "corr-integrated-protocol-evidence",
  });
  const result = await adapter.validateRuntime({
    path: dirname(fixture.fake.executablePath),
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
  });
  assert.equal(result.ok, true);
  const runDirectory = join(evidenceRoot, "run-integrated-protocol-evidence");
  assert.deepEqual((await readdir(runDirectory)).sort(), [
    "private.json",
    "protocol-private.json",
    "protocol-schemas",
    "protocol-summary.json",
    "protocol-transcript.json",
    "summary.json",
  ]);
  const protocolPrivate = await readFile(join(runDirectory, "protocol-private.json"), "utf8");
  const protocolSummaryText = await readFile(join(runDirectory, "protocol-summary.json"), "utf8");
  assert.match(protocolPrivate, new RegExp(fixture.fake.executablePath.replaceAll("/", "\\/"), "u"));
  assert.doesNotMatch(protocolSummaryText, new RegExp(fixture.fake.executablePath.replaceAll("/", "\\/"), "u"));
  assert.doesNotMatch(protocolSummaryText, /resolvedExecutablePath|snapshotExecutablePath|jsonSchemaDirectory|exactJsonArgv/iu);
  const protocolSummary = JSON.parse(protocolSummaryText) as Record<string, unknown>;
  assert.equal(protocolSummary.reproductionCommand, "npm ci && npm run protocol:validate");
  const schema = JSON.parse(
    await readFile(new URL("../evidence/protocol-validation-run.schema.json", import.meta.url), "utf8"),
  ) as { required: string[] };
  assert.equal(schema.required.every((key) => key in protocolSummary), true);
  assert.equal((await lstat(join(runDirectory, "protocol-schemas"))).mode & 0o777, 0o700);
});

test("protocol failures keep the frozen base v1 summary valid and retain the exact companion code", async () => {
  const fixture = await compatibilityFixture({ manifestBuild: "codex-cli 0.0.0" });
  const evidenceRoot = join(dirname(fixture.manifestPath), "failed-evidence");
  const runId = "run-protocol-failure-evidence";
  const result = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    evidenceRoot,
    runId: () => runId,
    correlationId: () => "corr-protocol-failure-evidence",
  }).validateRuntime({ path: dirname(fixture.fake.executablePath) });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "unsupported_runtime_build");
  const base = JSON.parse(await readFile(join(evidenceRoot, runId, "summary.json"), "utf8")) as {
    result: string;
    failureCode?: string;
  };
  const protocol = JSON.parse(
    await readFile(join(evidenceRoot, runId, "protocol-summary.json"), "utf8"),
  ) as { result: string; failureCode: string };
  assert.equal(base.result, "failed");
  assert.equal(base.failureCode, undefined);
  assert.deepEqual(protocol, {
    ...protocol,
    result: "failed",
    failureCode: "unsupported_runtime_build",
  });
});

async function validateFixture(
  fixture: Awaited<ReturnType<typeof compatibilityFixture>>,
  attemptId: string,
  stagingName: string,
) {
  return validateSnapshotCompatibility({
    attemptId,
    snapshot: fixture.snapshot,
    manifestPath: fixture.manifestPath,
    environment: fixture.profile.childEnvironment,
    workingDirectory: fixture.profile.workingDirectory,
    stagingDirectory: join(fixture.profile.runtimeRoot, stagingName),
    versionTimeoutMs: 1_500,
    generatorTimeoutMs: fixture.afterManifestBehavior === "generator-timeout" ? 500 : 1_500,
    generatorShutdownStepMs: 50,
  });
}

async function compatibilityFixture(options: {
  readonly manifestBuild?: string;
  readonly tamperJsonDigest?: boolean;
  readonly addMissingRequiredMethod?: boolean;
  readonly afterManifestBehavior?: FakeCodexBehavior;
} = {}) {
  const root = await mkdtemp(join(tmpdir(), "projectos-runtime-compatibility-"));
  const fake = await createFakeCodexRuntime(join(root, "bin"), "success");
  const profile = await createIsolatedRuntimeProfile({ baseDirectory: join(root, "runs") });
  const snapshot = await createExecutableSnapshot({
    sourcePath: fake.executablePath,
    instanceDirectory: profile.runtimeRoot,
  });
  const generated = await generateProtocolSchemas({
    executablePath: snapshot.executablePath,
    stagingDirectory: join(profile.runtimeRoot, "manifest-generated"),
    environment: profile.childEnvironment,
    timeoutMs: 1_500,
    shutdownStepMs: 50,
  });
  const methods = await extractGeneratedProtocolMethods(generated.jsonDirectory);
  const tamperedFiles = generated.jsonBundle.files.map((file, index) =>
    index === 0 && options.tamperJsonDigest ? { ...file, sha256: "f".repeat(64) } : file,
  );
  const json = options.tamperJsonDigest
    ? {
        ...generated.jsonBundle,
        files: tamperedFiles,
        aggregateSha256: sha256(schemaTreeAggregateBytes(tamperedFiles)),
      }
    : generated.jsonBundle;
  const manifest: SupportedRuntimeManifest = {
    formatVersion: 1,
    manifestId: "test-runtime-manifest",
    runtime: {
      build: options.manifestBuild ?? "codex-cli 9.8.7",
      platform: process.platform,
      architecture: process.arch,
      binaryContentSha256: snapshot.binaryContentSha256,
    },
    generation: {
      jsonArgv: ["app-server", "generate-json-schema", "--out", "$JSON_OUT"],
      typescriptArgv: ["app-server", "generate-ts", "--out", "$TS_OUT"],
      digestAlgorithm: PROTOCOL_DIGEST_ALGORITHM,
    },
    schemas: { json, typescript: generated.typescriptBundle },
    requiredMethods: {
      ...methods,
      clientRequests: options.addMissingRequiredMethod
        ? [...methods.clientRequests, "thread/start"].sort()
        : methods.clientRequests,
      recognizedForbidden: ["item/tool/call"],
    },
    enabledDispatch: { clientRequests: ["initialize"], clientNotifications: ["initialized"] },
  };
  const manifestPath = join(root, "manifest.json");
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  if (options.afterManifestBehavior) {
    await writeFile(fake.behaviorPath, `${options.afterManifestBehavior}\n`, { mode: 0o600 });
  }
  return { fake, profile, snapshot, manifestPath, afterManifestBehavior: options.afterManifestBehavior };
}

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
