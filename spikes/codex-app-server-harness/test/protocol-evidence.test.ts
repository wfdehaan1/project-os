import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { access, chmod, lstat, mkdtemp, readFile, readdir, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { promisify } from "node:util";
import test from "node:test";
import { Ajv2020 } from "ajv/dist/2020.js";

import { PROTOCOL_DIGEST_ALGORITHM, sha256, schemaTreeAggregateBytes } from "../src/adapters/codex/protocol-contract.ts";
import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";
import { createIsolatedRuntimeProfile } from "../src/adapters/codex/runtime-profile.ts";
import { FAILURE_CODES } from "../src/core/failures.ts";
import type { PrivateRunEvidence } from "../src/evidence/evidence-schema.ts";
import { EvidenceWriteError, writeRunEvidence } from "../src/evidence/evidence-recorder.ts";
import {
  sanitizeProtocolEvidence,
} from "../src/evidence/protocol-evidence-sanitizer.ts";
import type {
  PrivateProtocolValidationEvidence,
  ProtocolEvidencePackage,
} from "../src/evidence/protocol-evidence-schema.ts";
import { createFakeRuntimeManifest } from "./fixtures/fake-runtime-manifest.ts";
import type { FakeCodexBehavior } from "./fixtures/fake-codex-runtime.ts";

const forbidden = "secret-protocol-canary-7dc6";
const execFileAsync = promisify(execFile);

test("protocol evidence and exact schema attachments stage atomically beside base v1 evidence", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-evidence-"));
  const sources = await schemaSources(root);
  const protocol = packageFixture(sources);
  const paths = await writeRunEvidence(baseEvidence(), join(root, "evidence"), protocol);

  assert.deepEqual((await readdir(paths.runDirectory)).sort(), [
    "private.json",
    "protocol-private.json",
    "protocol-schemas",
    "protocol-summary.json",
    "protocol-transcript.json",
    "summary.json",
  ]);
  for (const path of [
    join(paths.runDirectory, "protocol-private.json"),
    join(paths.runDirectory, "protocol-summary.json"),
    join(paths.runDirectory, "protocol-transcript.json"),
    join(paths.runDirectory, "protocol-schemas", "attempt-1", "json", "schema.json"),
    join(paths.runDirectory, "protocol-schemas", "attempt-1", "typescript", "schema.ts"),
  ]) {
    assert.equal((await lstat(path)).mode & 0o777, 0o600);
  }
  const baseSummary = JSON.parse(await readFile(paths.sanitizedSummaryPath, "utf8")) as {
    schemaVersion: number;
  };
  assert.equal(baseSummary.schemaVersion, 1);
});

test("shareable protocol summary is reproducible and contains no raw payload or private values", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-sanitize-"));
  const protocol = packageFixture(await schemaSources(root));
  const summary = sanitizeProtocolEvidence(protocol.privateEvidence);
  const serialized = JSON.stringify(summary);
  assert.equal(summary.binaryContentSha256, "b".repeat(64));
  assert.deepEqual(summary.logicalArgv.json, [
    "$CODEX",
    "app-server",
    "generate-json-schema",
    "--out",
    "$JSON_OUT",
  ]);
  assert.doesNotMatch(serialized, /\/private\/fixture|secret-protocol-canary|raw|params|stderr/iu);
  assert.equal(summary.transcript[0]?.classification, "sent_experimental_api_disabled");
});

test("sanitizer validates every attempt and uses each attempt's method allowlist", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-attempt-sanitize-"));
  const fixture = packageFixture(await schemaSources(root));
  const baseAttempt = fixture.privateEvidence.attempts[0]!;
  const firstAttempt = {
    ...baseAttempt,
    failureCode: "schema_generation_failed" as const,
    compatibilityOutcome: "incompatible" as const,
    diagnosticReference: "protocol-first",
    requiredMethods: {
      clientRequests: ["initialize"],
      clientNotifications: ["initialized"],
      serverNotifications: ["first/only"],
      serverRequests: ["item/tool/call"],
      recognizedForbidden: ["item/tool/call"],
    },
    transcript: [{
      attemptId: "attempt-1",
      sequence: 1,
      direction: "inbound_notification" as const,
      method: "second/only",
      requestIdClass: "none" as const,
      classification: "semantic" as const,
    }],
  };
  const secondAttempt = {
    ...baseAttempt,
    generation: 2 as const,
    attemptId: "attempt-2",
    correlationId: "corr-protocol-test:attempt-2",
    requiredMethods: {
      ...baseAttempt.requiredMethods!,
      serverNotifications: ["second/only"],
    },
    transcript: [],
  };
  const summary = sanitizeProtocolEvidence({
    ...fixture.privateEvidence,
    reproductionCommand: "npm ci && npm run protocol:validate -- --restart",
    attempts: [firstAttempt, secondAttempt],
  });
  assert.equal(summary.transcript[0]?.method, "$UNRECOGNIZED");

  assert.throws(
    () => sanitizeProtocolEvidence({
      ...fixture.privateEvidence,
      reproductionCommand: "npm ci && npm run protocol:validate -- --restart",
      attempts: [{ ...firstAttempt, correlationId: "/private/unsafe" }, secondAttempt],
    }),
    /evidence_write_failed/u,
  );
});

test("sanitizer rejects contradictory pass records and mismatched terminal failures", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-truthfulness-"));
  const fixture = packageFixture(await schemaSources(root));
  const attempt = fixture.privateEvidence.attempts[0]!;
  for (const invalidAttempt of [
    { ...attempt, compatibilityOutcome: "incompatible" as const },
    { ...attempt, schemas: null },
    { ...attempt, failureCode: "spawn_failed" as const },
  ]) {
    assert.throws(
      () => sanitizeProtocolEvidence({
        ...fixture.privateEvidence,
        attempts: [invalidAttempt],
      }),
      /evidence_write_failed/u,
    );
  }
  assert.throws(
    () => sanitizeProtocolEvidence({
      ...fixture.privateEvidence,
      result: "failed",
      failureCode: "spawn_failed",
      attempts: [{ ...attempt, failureCode: "initialization_timeout" }],
    }),
    /evidence_write_failed/u,
  );
});

test("unsafe unapproved method text is redacted before safe-method validation", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-unsafe-method-"));
  const fixture = packageFixture(await schemaSources(root));
  const attempt = fixture.privateEvidence.attempts[0]!;
  const summary = sanitizeProtocolEvidence({
    ...fixture.privateEvidence,
    attempts: [{
      ...attempt,
      transcript: [{
        ...attempt.transcript[0]!,
        method: "/private/unsafe method\u0007",
        classification: "unknown",
      }],
    }],
  });
  assert.equal(summary.transcript[0]?.method, "$UNRECOGNIZED");
  assert.doesNotMatch(JSON.stringify(summary), /private|unsafe method/iu);
});

test("Draft 2020-12 evidence schema validates produced summaries and rejects negative instances", async () => {
  const schema = JSON.parse(
    await readFile(new URL("../evidence/protocol-validation-run.schema.json", import.meta.url), "utf8"),
  ) as object;
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-schema-validator-"));
  const summary = sanitizeProtocolEvidence(packageFixture(await schemaSources(root)).privateEvidence);
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  const validate = ajv.compile(schema);
  assert.equal(validate(summary), true, JSON.stringify(validate.errors));

  const firstFile = summary.schemas?.json.files[0];
  assert.ok(firstFile);
  const invalidSummaries: unknown[] = [
    { ...summary, unexpected: true },
    {
      ...summary,
      schemas: {
        ...summary.schemas,
        json: {
          ...summary.schemas.json,
          files: [{ ...firstFile, path: "/private/schema.json" }],
        },
      },
    },
    {
      ...summary,
      attempts: summary.attempts.map((attempt) => ({ ...attempt, generation: 2 })),
    },
    {
      ...summary,
      attempts: summary.attempts.map((attempt) => ({
        ...attempt,
        scope: "concurrent_instance",
      })),
    },
    {
      ...summary,
      transcript: summary.transcript.map((entry) => ({ ...entry, method: "/private/method" })),
    },
  ];
  for (const invalidSummary of invalidSummaries) assert.equal(validate(invalidSummary), false);
});

test("sanitizer rejects runtime-invalid transcript structural fields", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-transcript-enum-"));
  const fixture = packageFixture(await schemaSources(root));
  const attempt = fixture.privateEvidence.attempts[0]!;
  assert.throws(
    () => sanitizeProtocolEvidence({
      ...fixture.privateEvidence,
      attempts: [{
        ...attempt,
        transcript: [{ ...attempt.transcript[0]!, direction: "private/canary" as never }],
      }],
    }),
    /evidence_write_failed/u,
  );
});

test("every normalized partial failure keeps private canaries out of shareable protocol evidence", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-failure-canary-"));
  const fixture = packageFixture(await schemaSources(root));
  for (const failureCode of FAILURE_CODES) {
    const firstAttempt = {
      ...fixture.privateEvidence.attempts[0]!,
      failureCode: failureCode === "restart_failed" ? "schema_generation_failed" as const : failureCode,
      underlyingFailureCode: null,
      compatibilityOutcome: "incompatible" as const,
      lifecycle: ["undiscovered", "discovered", "failed"] as const,
      shutdownOutcome: "not_started" as const,
      resolvedExecutablePath: `/private/${forbidden}/${failureCode}/codex`,
      snapshotExecutablePath: `/private/${forbidden}/${failureCode}/snapshot`,
      privateCanary: `${forbidden}-${failureCode}`,
    };
    const attempts = failureCode === "restart_failed"
      ? [
          firstAttempt,
          {
            ...firstAttempt,
            generation: 2 as const,
            attemptId: "attempt-2",
            correlationId: "corr-protocol-test:attempt-2",
            failureCode,
            underlyingFailureCode: "schema_generation_failed" as const,
            transcript: firstAttempt.transcript.map((entry) => ({
              ...entry,
              attemptId: "attempt-2",
            })),
          },
        ]
      : [firstAttempt];
    const privateEvidence: PrivateProtocolValidationEvidence = {
      ...fixture.privateEvidence,
      result: "failed",
      failureCode,
      reproductionCommand: failureCode === "restart_failed"
        ? "npm ci && npm run protocol:validate -- --restart"
        : fixture.privateEvidence.reproductionCommand,
      attempts,
    };
    const serialized = JSON.stringify(sanitizeProtocolEvidence(privateEvidence));
    assert.doesNotMatch(serialized, new RegExp(forbidden, "u"));
    assert.doesNotMatch(serialized, /\/private\//u);
  }
});

test("real adapter failure paths produce safe evidence, including a true two-attempt restart", async () => {
  for (const [behavior, expectedCode] of [
    ["version-probe-failure", "version_probe_failed"],
    ["generator-nonzero", "schema_generation_failed"],
    ["ignore-term", "initialization_timeout"],
  ] as const) {
    const { result, protocol } = await captureAdapterFailure(behavior);
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.code, expectedCode);
    assert.ok(protocol);
    const serialized = JSON.stringify(sanitizeProtocolEvidence(protocol.privateEvidence));
    assert.doesNotMatch(serialized, /\/private\/|resolvedExecutablePath|snapshotExecutablePath|stderr/iu);
  }

  const nonExecutable = await captureAdapterFailure("success", true);
  assert.equal(nonExecutable.result.ok, false);
  if (!nonExecutable.result.ok) assert.equal(nonExecutable.result.code, "runtime_not_executable");
  const nonExecutableProtocol = nonExecutable.protocol;
  assert.ok(nonExecutableProtocol);
  assert.doesNotThrow(() => sanitizeProtocolEvidence(nonExecutableProtocol.privateEvidence));

  const restarted = await captureAdapterFailure("malformed", false, true);
  assert.equal(restarted.result.ok, false);
  if (!restarted.result.ok) assert.equal(restarted.result.code, "restart_failed");
  assert.ok(restarted.protocol);
  const restartSummary = sanitizeProtocolEvidence(restarted.protocol.privateEvidence);
  assert.equal(restartSummary.attempts.length, 2);
  assert.equal(restartSummary.attempts[0]?.failureCode, "malformed_handshake_response");
  assert.equal(restartSummary.attempts[1]?.failureCode, "restart_failed");
  assert.equal(restartSummary.attempts[1]?.underlyingFailureCode, "malformed_handshake_response");
  assert.equal(restartSummary.reproductionCommand, "npm ci && npm run protocol:validate -- --restart");

  const fixture = await createFakeRuntimeManifest("success");
  const evidenceFailure = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: async () => { throw new Error(`${forbidden}-evidence-writer`); },
  }).validateRuntime({ path: dirname(fixture.fake.executablePath), initializationTimeoutMs: 750 });
  assert.equal(evidenceFailure.ok, false);
  if (!evidenceFailure.ok) assert.equal(evidenceFailure.code, "evidence_write_failed");
  assert.doesNotMatch(JSON.stringify(evidenceFailure), new RegExp(forbidden, "u"));
});

test("concurrent-profile crossover is scoped only in companion protocol evidence", async () => {
  const fixture = await createFakeRuntimeManifest("success");
  let protocol: ProtocolEvidencePackage | undefined;
  const result = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    createProfile: async (options = {}) => {
      const profile = await createIsolatedRuntimeProfile(options);
      assert.ok(options.normalProfileRoot);
      await writeFile(
        join(options.normalProfileRoot, "config.toml"),
        'profile_marker = "crossed-over"\n',
        { mode: 0o600 },
      );
      return profile;
    },
    writeEvidence: async (...arguments_) => {
      protocol = arguments_[2];
      return {
        runDirectory: "/private/evidence/run",
        privateEvidencePath: "/private/evidence/run/private.json",
        sanitizedSummaryPath: "/private/evidence/run/summary.json",
      };
    },
  }).validateRuntime({
    path: dirname(fixture.fake.executablePath),
    initializationTimeoutMs: 750,
    shutdownTimeoutMs: 100,
  });

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.code, "isolation_failed");
    assert.equal("scope" in result, false);
  }
  assert.ok(protocol);
  assert.equal(protocol.privateEvidence.attempts[0]?.scope, "concurrent_instance");
  assert.equal(
    sanitizeProtocolEvidence(protocol.privateEvidence).attempts[0]?.scope,
    "concurrent_instance",
  );
});

test("attachment symlinks and traversal fail without publishing a partial run", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-unsafe-"));
  const sources = await schemaSources(root);
  await symlink(join(sources.jsonDirectory, "schema.json"), join(sources.jsonDirectory, "linked.json"));
  const evidenceRoot = join(root, "evidence");
  await assert.rejects(
    writeRunEvidence(baseEvidence(), evidenceRoot, packageFixture(sources)),
    (error: unknown) => error instanceof EvidenceWriteError,
  );
  await assert.rejects(access(join(evidenceRoot, "run-protocol-test")));

  const safeSources = await schemaSources(join(root, "safe"));
  const traversing = packageFixture(safeSources);
  await assert.rejects(
    writeRunEvidence(baseEvidence(), join(root, "evidence-traversal"), {
      ...traversing,
      attachments: [{
        ...traversing.attachments[0]!,
        sourceDirectory: safeSources.jsonDirectory,
        destinationRelativePath: "../escape",
      }],
    }),
    (error: unknown) => error instanceof EvidenceWriteError,
  );

  const shortSocketRoot = await mkdtemp("/tmp/projectos-pe-");
  const socketSources = await schemaSources(shortSocketRoot);
  await execFileAsync("mkfifo", [join(socketSources.jsonDirectory, "non-regular.fifo")]);
  await assert.rejects(
    writeRunEvidence(baseEvidence(), join(root, "evidence-fifo"), packageFixture(socketSources)),
    (error: unknown) => error instanceof EvidenceWriteError,
  );
  await assert.rejects(access(join(root, "evidence-fifo", "run-protocol-test")));
});

test("same-size schema mutation fails digest verification before evidence publication", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-attachment-digest-"));
  const sources = await schemaSources(root);
  const protocol = packageFixture(sources);
  await writeFile(join(sources.jsonDirectory, "schema.json"), "[]\n", { mode: 0o600 });
  const evidenceRoot = join(root, "evidence");
  await assert.rejects(
    writeRunEvidence(baseEvidence(), evidenceRoot, protocol),
    (error: unknown) => error instanceof EvidenceWriteError,
  );
  await assert.rejects(access(join(evidenceRoot, "run-protocol-test")));
});

async function captureAdapterFailure(
  behavior: FakeCodexBehavior,
  makeNonExecutable = false,
  restart = false,
) {
  const fixture = await createFakeRuntimeManifest("success");
  await writeFile(fixture.fake.behaviorPath, `${behavior}\n`, { mode: 0o600 });
  if (makeNonExecutable) await chmod(fixture.fake.executablePath, 0o600);
  let protocol: ProtocolEvidencePackage | undefined;
  const result = await new CodexAppServerAdapter({
    manifestPath: fixture.manifestPath,
    writeEvidence: async (...arguments_) => {
      protocol = arguments_[2];
      return {
        runDirectory: "/private/evidence/run",
        privateEvidencePath: "/private/evidence/run/private.json",
        sanitizedSummaryPath: "/private/evidence/run/summary.json",
      };
    },
  }).validateRuntime({
    path: dirname(fixture.fake.executablePath),
    initializationTimeoutMs: 250,
    shutdownTimeoutMs: 50,
    ...(restart ? { restart: true } : {}),
  });
  return { result, protocol };
}

async function schemaSources(root: string) {
  const jsonDirectory = join(root, "private", "json");
  const typescriptDirectory = join(root, "private", "typescript");
  await import("node:fs/promises").then(({ mkdir }) =>
    Promise.all([
      mkdir(jsonDirectory, { recursive: true, mode: 0o700 }),
      mkdir(typescriptDirectory, { recursive: true, mode: 0o700 }),
    ]),
  );
  await writeFile(join(jsonDirectory, "schema.json"), "{}\n", { mode: 0o600 });
  await writeFile(join(typescriptDirectory, "schema.ts"), "export {};\n", { mode: 0o600 });
  return { jsonDirectory, typescriptDirectory };
}

function packageFixture(sources: Awaited<ReturnType<typeof schemaSources>>): ProtocolEvidencePackage {
  const jsonFile = { path: "schema.json", sha256: sha256("{}") };
  const typescriptFile = { path: "schema.ts", sha256: sha256("export {};\n") };
  const jsonBundle = {
    algorithm: PROTOCOL_DIGEST_ALGORITHM,
    files: [jsonFile],
    aggregateSha256: sha256(schemaTreeAggregateBytes([jsonFile])),
  } as const;
  const typescriptBundle = {
    algorithm: PROTOCOL_DIGEST_ALGORITHM,
    files: [typescriptFile],
    aggregateSha256: sha256(schemaTreeAggregateBytes([typescriptFile])),
  } as const;
  const privateEvidence: PrivateProtocolValidationEvidence = {
    schemaVersion: 1,
    runId: "run-protocol-test",
    correlationId: "corr-protocol-test",
    result: "passed",
    failureCode: null,
    reproductionCommand: "npm ci && npm run protocol:validate",
    attempts: [{
      generation: 1,
      attemptId: "attempt-1",
      correlationId: "corr-protocol-test:attempt-1",
      failureCode: null,
      underlyingFailureCode: null,
      scope: null,
      compatibilityOutcome: "compatible",
      detectedBuild: "codex-cli 0.145.0",
      platform: "darwin",
      architecture: "arm64",
      binaryContentSha256: "b".repeat(64),
      manifestId: "manifest-test",
      manifestDigest: "c".repeat(64),
      manifest: null,
      resolvedExecutablePath: "/private/fixture/bin/codex",
      snapshotExecutablePath: "/private/fixture/run/snapshot/codex",
      jsonSchemaDirectory: sources.jsonDirectory,
      typescriptSchemaDirectory: sources.typescriptDirectory,
      exactJsonArgv: ["/private/fixture/run/snapshot/codex", "app-server", "generate-json-schema", "--out", sources.jsonDirectory],
      exactTypescriptArgv: ["/private/fixture/run/snapshot/codex", "app-server", "generate-ts", "--out", sources.typescriptDirectory],
      schemas: {
        json: jsonBundle,
        typescript: typescriptBundle,
      },
      requiredMethods: {
        clientRequests: ["initialize"],
        clientNotifications: ["initialized"],
        serverNotifications: ["error"],
        serverRequests: ["item/tool/call"],
        recognizedForbidden: ["item/tool/call"],
      },
      detectedMethods: {
        clientRequests: ["initialize"],
        clientNotifications: ["initialized"],
        serverNotifications: ["error"],
        serverRequests: ["item/tool/call"],
      },
      enabledDispatch: { clientRequests: ["initialize"], clientNotifications: ["initialized"] },
      lifecycle: ["undiscovered", "discovered", "starting", "initializing", "initialized", "stopping", "stopped"],
      shutdownOutcome: "clean_exit",
      preflightProcessGroupsReaped: true,
      processOwnership: { childPid: 1234, processGroupId: 1234, reaped: true },
      diagnosticReference: null,
      transcript: [{
        attemptId: "attempt-1",
        sequence: 1,
        direction: "outbound_request",
        method: "initialize",
        requestIdClass: "initialize",
        classification: "sent_experimental_api_disabled",
      }],
      privateCanary: forbidden,
    }],
  };
  return {
    privateEvidence,
    attachments: [
      {
        kind: "json",
        sourceDirectory: sources.jsonDirectory,
        destinationRelativePath: "protocol-schemas/attempt-1/json",
        expectedBundle: jsonBundle,
      },
      {
        kind: "typescript",
        sourceDirectory: sources.typescriptDirectory,
        destinationRelativePath: "protocol-schemas/attempt-1/typescript",
        expectedBundle: typescriptBundle,
      },
    ],
  };
}

function baseEvidence(): PrivateRunEvidence {
  return {
    schemaVersion: 1,
    runId: "run-protocol-test",
    correlationId: "corr-protocol-test",
    startedAt: "2026-08-01T10:00:00.000Z",
    completedAt: "2026-08-01T10:00:01.000Z",
    harnessVersion: "0.1.0",
    nodeVersion: "v24.18.1",
    runtimeVersion: "codex-cli 0.145.0",
    candidateExecutablePath: "/private/fixture/bin/codex",
    resolvedExecutablePath: "/private/fixture/bin/codex",
    runtimePaths: {
      runtimeRoot: "/private/fixture/run",
      codexHome: "/private/fixture/run/codex-home",
      codexSqliteHome: "/private/fixture/run/codex-sqlite-home",
      disposableHome: "/private/fixture/run/home",
      workingDirectory: "/private/fixture/run/work",
      temporaryDirectory: "/private/fixture/run/tmp",
      configPath: "/private/fixture/run/codex-home/config.toml",
    },
    strictConfigurationFingerprint: "d".repeat(64),
    allowedEnvironmentNames: ["CODEX_HOME"],
    environmentFingerprints: { CODEX_HOME: "e".repeat(64) },
    lifecycle: ["undiscovered", "discovered", "starting", "initializing", "initialized", "stopping", "stopped"],
    handshakeOutcome: "initialized",
    shutdownOutcome: "clean_exit",
    isolationComparison: "unchanged",
    result: "passed",
    failureCode: undefined,
    reproductionCommand: "npm ci && npm run validate:full",
  };
}
