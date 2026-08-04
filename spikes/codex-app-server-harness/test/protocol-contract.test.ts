import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { Ajv2020 } from "ajv/dist/2020.js";

import {
  PROTOCOL_DIGEST_ALGORITHM,
  DEFAULT_PROTOCOL_LIMITS,
  collectProtocolSchemaBundle,
  compareSupportedProtocol,
  createProtocolBoundary,
  extractGeneratedProtocolMethods,
  parseSupportedRuntimeManifest,
  schemaTreeAggregateBytes,
  sha256,
  type SupportedRuntimeManifest,
} from "../src/adapters/codex/protocol-contract.ts";
import {
  generateProtocolSchemas,
  ProtocolSchemaGenerationError,
} from "../src/adapters/codex/protocol-schema-generator.ts";
import { writeFakeProtocolSchemaBundle } from "./fixtures/fake-protocol-schema-bundle.ts";

test("schema tree digests are deterministic across roots and creation order", async () => {
  const firstRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-tree-a-"));
  const secondRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-tree-b-"));
  const first = await writeFakeProtocolSchemaBundle(firstRoot);
  const second = await writeFakeProtocolSchemaBundle(secondRoot, { reverseCreationOrder: true });

  const firstJson = await collectProtocolSchemaBundle(first.jsonDirectory, "json");
  const secondJson = await collectProtocolSchemaBundle(second.jsonDirectory, "json");
  const firstTypescript = await collectProtocolSchemaBundle(first.typescriptDirectory, "typescript");
  const secondTypescript = await collectProtocolSchemaBundle(second.typescriptDirectory, "typescript");

  assert.equal(firstJson.algorithm, PROTOCOL_DIGEST_ALGORITHM);
  assert.deepEqual(firstJson, secondJson);
  assert.deepEqual(firstTypescript, secondTypescript);
  assert.deepEqual(firstJson.files.map((file) => file.path), [
    "ClientNotification.json",
    "ClientRequest.json",
    "ServerNotification.json",
    "ServerRequest.json",
    "nested/Other.json",
  ]);
});

test("method extraction preserves protocol direction and exact stable names", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-methods-"));
  const bundle = await writeFakeProtocolSchemaBundle(root);
  assert.deepEqual(await extractGeneratedProtocolMethods(bundle.jsonDirectory), {
    clientRequests: ["account/read", "initialize", "thread/start"],
    clientNotifications: ["initialized"],
    serverNotifications: ["error", "thread/started"],
    serverRequests: ["item/tool/call"],
  });
});

test("one-byte drift changes only the affected tree digest", async () => {
  const firstRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-drift-a-"));
  const secondRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-drift-b-"));
  const first = await writeFakeProtocolSchemaBundle(firstRoot);
  const second = await writeFakeProtocolSchemaBundle(secondRoot, { drift: true });

  assert.deepEqual(
    await collectProtocolSchemaBundle(first.jsonDirectory, "json"),
    await collectProtocolSchemaBundle(second.jsonDirectory, "json"),
  );
  assert.notEqual(
    (await collectProtocolSchemaBundle(first.typescriptDirectory, "typescript")).aggregateSha256,
    (await collectProtocolSchemaBundle(second.typescriptDirectory, "typescript")).aggregateSha256,
  );
});

test("JSON schema digests ignore object-key emission order but preserve semantic drift", async () => {
  const firstRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-json-order-a-"));
  const secondRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-json-order-b-"));
  await writeFile(join(firstRoot, "schema.json"), '{"b":1,"a":{"d":2,"c":3}}\n');
  await writeFile(join(secondRoot, "schema.json"), '{"a":{"c":3,"d":2},"b":1}\n');
  assert.deepEqual(
    await collectProtocolSchemaBundle(firstRoot, "json"),
    await collectProtocolSchemaBundle(secondRoot, "json"),
  );

  await writeFile(join(secondRoot, "schema.json"), '{"a":{"c":4,"d":2},"b":1}\n');
  assert.notEqual(
    (await collectProtocolSchemaBundle(firstRoot, "json")).aggregateSha256,
    (await collectProtocolSchemaBundle(secondRoot, "json")).aggregateSha256,
  );
});

test("schema collection rejects malformed JSON and unsafe filesystem entries", async () => {
  const malformedRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-malformed-"));
  await writeFile(join(malformedRoot, "bad.json"), "{bad", { mode: 0o600 });
  await assert.rejects(collectProtocolSchemaBundle(malformedRoot, "json"), /invalid_manifest/u);

  const linkedRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-link-"));
  const target = join(linkedRoot, "target.json");
  await writeFile(target, "{}", { mode: 0o600 });
  await symlink(target, join(linkedRoot, "linked.json"));
  await assert.rejects(collectProtocolSchemaBundle(linkedRoot, "json"), /invalid_manifest/u);
});

test("schema collection accepts every exact limit and rejects limit plus one", async () => {
  const fileBytesRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-file-bytes-"));
  await writeFile(join(fileBytesRoot, "schema.json"), "{}\n");
  await collectProtocolSchemaBundle(fileBytesRoot, "json", { maximumFileBytes: 3 });
  await assert.rejects(
    collectProtocolSchemaBundle(fileBytesRoot, "json", { maximumFileBytes: 2 }),
    /invalid_manifest/u,
  );

  const bundleBytesRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-bundle-bytes-"));
  await writeFile(join(bundleBytesRoot, "a.json"), "{}\n");
  await writeFile(join(bundleBytesRoot, "b.json"), "{}\n");
  await collectProtocolSchemaBundle(bundleBytesRoot, "json", { maximumBundleBytes: 6 });
  await assert.rejects(
    collectProtocolSchemaBundle(bundleBytesRoot, "json", { maximumBundleBytes: 5 }),
    /invalid_manifest/u,
  );

  await collectProtocolSchemaBundle(bundleBytesRoot, "json", { maximumFiles: 2 });
  await assert.rejects(
    collectProtocolSchemaBundle(bundleBytesRoot, "json", { maximumFiles: 1 }),
    /invalid_manifest/u,
  );

  const exactDepthRoot = await mkdtemp(join(tmpdir(), "projectos-protocol-depth-exact-"));
  const exactDepth = join(exactDepthRoot, "one", "two");
  await mkdir(exactDepth, { recursive: true });
  await writeFile(join(exactDepth, "schema.json"), "{}\n");
  await collectProtocolSchemaBundle(exactDepthRoot, "json", { maximumDepth: 2 });
  const overDepth = join(exactDepth, "three");
  await mkdir(overDepth);
  await writeFile(join(overDepth, "schema.json"), "{}\n");
  await assert.rejects(
    collectProtocolSchemaBundle(exactDepthRoot, "json", { maximumDepth: 2 }),
    /invalid_manifest/u,
  );
});

test("manifest parsing and comparison fail closed on inventory, digest, and method drift", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-manifest-"));
  const bundle = await writeFakeProtocolSchemaBundle(root);
  const json = await collectProtocolSchemaBundle(bundle.jsonDirectory, "json");
  const typescript = await collectProtocolSchemaBundle(bundle.typescriptDirectory, "typescript");
  const manifest = manifestFixture(json, typescript);
  const parsed = parseSupportedRuntimeManifest(JSON.stringify(manifest));
  const detectedMethods = await extractGeneratedProtocolMethods(bundle.jsonDirectory);

  const compatible = compareSupportedProtocol({
    manifest: parsed,
    detectedBuild: manifest.runtime.build,
    detectedPlatform: manifest.runtime.platform,
    detectedArchitecture: manifest.runtime.architecture,
    binaryContentSha256: manifest.runtime.binaryContentSha256,
    jsonBundle: json,
    typescriptBundle: typescript,
    detectedMethods,
  });
  assert.equal(compatible.ok, true);

  assert.equal(compareSupportedProtocol({ ...compatible.input, detectedBuild: "codex-cli 0.0.0" }).ok, false);
  assert.equal(
    compareSupportedProtocol({
      ...compatible.input,
      manifest: { ...parsed, enabledDispatch: { clientRequests: ["thread/start"], clientNotifications: [] } },
    }).ok,
    false,
  );
  assert.throws(
    () => parseSupportedRuntimeManifest(JSON.stringify({ ...manifest, formatVersion: 99 })),
    /invalid_manifest/u,
  );
  assert.throws(
    () => parseSupportedRuntimeManifest(JSON.stringify({
      ...manifest,
      schemas: {
        ...manifest.schemas,
        json: { ...manifest.schemas.json, aggregateSha256: "f".repeat(64) },
      },
    })),
    /invalid_manifest/u,
  );
  assert.throws(
    () => parseSupportedRuntimeManifest(JSON.stringify({
      ...manifest,
      runtime: { ...manifest.runtime, build: "codex-cli 0.145.0 /Users/private" },
    })),
    /invalid_manifest/u,
  );

  for (const invalidManifest of [
    { ...manifest, unexpected: true },
    { ...manifest, runtime: { ...manifest.runtime, unexpected: true } },
    { ...manifest, runtime: { ...manifest.runtime, platform: "" } },
    { ...manifest, requiredMethods: { ...manifest.requiredMethods, unexpected: [] } },
    {
      ...manifest,
      requiredMethods: { ...manifest.requiredMethods, clientRequests: ["account/read", "thread/start"] },
    },
    {
      ...manifest,
      requiredMethods: { ...manifest.requiredMethods, recognizedForbidden: [] },
    },
    {
      ...manifest,
      requiredMethods: {
        ...manifest.requiredMethods,
        serverNotifications: ["error", "item/tool/call", "thread/started"],
      },
    },
  ]) {
    assert.throws(
      () => parseSupportedRuntimeManifest(JSON.stringify(invalidManifest)),
      /invalid_manifest/u,
    );
  }

  const emptyFiles = [] as const;
  const excessiveFiles = Array.from(
    { length: DEFAULT_PROTOCOL_LIMITS.maximumFiles + 1 },
    (_, index) => ({ path: `schema-${String(index).padStart(4, "0")}.json`, sha256: "b".repeat(64) }),
  );
  const duplicateFiles = [
    { path: "duplicate.json", sha256: "b".repeat(64) },
    { path: "duplicate.json", sha256: "c".repeat(64) },
  ];
  const unsafePathFiles = [{ path: "a/..", sha256: "b".repeat(64) }];
  const unsortedFiles = [...manifest.schemas.json.files].reverse();
  for (const files of [
    emptyFiles,
    excessiveFiles,
    duplicateFiles,
    unsafePathFiles,
    unsortedFiles,
  ]) {
    assert.throws(
      () => parseSupportedRuntimeManifest(JSON.stringify({
        ...manifest,
        schemas: {
          ...manifest.schemas,
          json: {
            algorithm: PROTOCOL_DIGEST_ALGORITHM,
            files,
            aggregateSha256: sha256(schemaTreeAggregateBytes(files)),
          },
        },
      })),
      /invalid_manifest/u,
    );
  }
});

test("Draft 2020-12 schemas compile and validate the committed manifest fail-closed", async () => {
  const manifest = parseSupportedRuntimeManifest(
    await readFile(new URL("../protocol/supported-runtime-manifest.json", import.meta.url), "utf8"),
  );
  const manifestSchema = JSON.parse(
    await readFile(new URL("../protocol/supported-runtime-manifest.schema.json", import.meta.url), "utf8"),
  ) as object;
  const evidenceSchema = JSON.parse(
    await readFile(new URL("../evidence/protocol-validation-run.schema.json", import.meta.url), "utf8"),
  ) as object;
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  const validateManifest = ajv.compile(manifestSchema);
  assert.doesNotThrow(() => ajv.compile(evidenceSchema));
  assert.equal(validateManifest(manifest), true, JSON.stringify(validateManifest.errors));

  const firstJsonFile = manifest.schemas.json.files[0]!;
  const invalidManifests: unknown[] = [
    { ...manifest, unexpected: true },
    {
      ...manifest,
      schemas: {
        ...manifest.schemas,
        json: {
          ...manifest.schemas.json,
          files: [{ ...firstJsonFile, path: "/private/schema.json" }, ...manifest.schemas.json.files.slice(1)],
        },
      },
    },
    {
      ...manifest,
      requiredMethods: {
        ...manifest.requiredMethods,
        clientRequests: manifest.requiredMethods.clientRequests.filter((method) => method !== "initialize"),
      },
    },
  ];
  for (const invalidManifest of invalidManifests) {
    assert.equal(validateManifest(invalidManifest), false);
  }
});

test("dispatch boundary enables initialize/initialized only and denies stable unlisted methods", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-boundary-"));
  const bundle = await writeFakeProtocolSchemaBundle(root);
  const json = await collectProtocolSchemaBundle(bundle.jsonDirectory, "json");
  const typescript = await collectProtocolSchemaBundle(bundle.typescriptDirectory, "typescript");
  const methods = await extractGeneratedProtocolMethods(bundle.jsonDirectory);
  const boundary = createProtocolBoundary(manifestFixture(json, typescript), methods);

  assert.doesNotThrow(() => boundary.assertClientRequest("initialize"));
  assert.doesNotThrow(() => boundary.assertClientNotification("initialized"));
  assert.throws(() => boundary.assertClientRequest("thread/start"), /unsupported_dispatch/u);
  assert.throws(() => boundary.assertClientRequest("future/method"), /unsupported_dispatch/u);
  assert.equal(boundary.classifyInbound("error", "server_notification"), "semantic_notification");
  assert.equal(boundary.classifyInbound("error", "server_request"), "unknown");
  assert.equal(boundary.classifyInbound("item/tool/call", "server_request"), "forbidden");
  assert.equal(boundary.classifyInbound("item/tool/call", "server_notification"), "unknown");
  assert.equal(boundary.classifyInbound("future/event", "server_notification"), "unknown");
});

test("schema generator uses exact stable argv without a shell or experimental flags", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-protocol-generator-"));
  const executable = join(root, "codex");
  const argvLog = join(root, "argv.jsonl");
  const script = `#!${process.execPath}\n` +
    `import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";\n` +
    `import { join } from "node:path";\n` +
    `appendFileSync(${JSON.stringify(argvLog)}, JSON.stringify(process.argv.slice(2)) + "\\n");\n` +
    `const out = process.argv.at(-1); mkdirSync(out, { recursive: true });\n` +
    `if (process.argv[3] === "generate-json-schema") writeFileSync(join(out, "schema.json"), "{}\\n");\n` +
    `else writeFileSync(join(out, "schema.ts"), "export {};\\n");\n`;
  await writeFile(executable, script, { mode: 0o500 });
  await chmod(executable, 0o500);

  const generated = await generateProtocolSchemas({
    executablePath: executable,
    stagingDirectory: join(root, "generated"),
    environment: { PATH: "/usr/bin:/bin" },
    timeoutMs: 1_500,
    shutdownStepMs: 50,
  });
  assert.deepEqual(
    (await readFile(argvLog, "utf8")).trim().split("\n").map((line) => JSON.parse(line)),
    [
      ["app-server", "generate-json-schema", "--out", generated.jsonDirectory],
      ["app-server", "generate-ts", "--out", generated.typescriptDirectory],
    ],
  );
});

test("schema generation reaps descendant processes and leaves unrelated groups alive", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-generator-ownership-"));
  const executable = join(root, "codex");
  const pidLog = join(root, "descendant-pids.txt");
  const script = `#!${process.execPath}\n` +
    `import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";\n` +
    `import { spawn } from "node:child_process";\n` +
    `import { join } from "node:path";\n` +
    `const out = process.argv.at(-1); mkdirSync(out, { recursive: true });\n` +
    `if (process.argv[3] === "generate-json-schema") writeFileSync(join(out, "schema.json"), "{}\\n");\n` +
    `else writeFileSync(join(out, "schema.ts"), "export {};\\n");\n` +
    `const descendant = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], { stdio: "ignore" });\n` +
    `appendFileSync(${JSON.stringify(pidLog)}, String(descendant.pid) + "\\n"); descendant.unref();\n`;
  await writeFile(executable, script, { mode: 0o500 });
  await chmod(executable, 0o500);
  const sentinel = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
    detached: process.platform !== "win32",
    stdio: "ignore",
  });
  try {
    await generateProtocolSchemas({
      executablePath: executable,
      stagingDirectory: join(root, "generated"),
      environment: { PATH: "/usr/bin:/bin" },
      timeoutMs: 1_500,
      shutdownStepMs: 500,
    });
    const descendantPids = (await readFile(pidLog, "utf8"))
      .trim()
      .split("\n")
      .map((value) => Number.parseInt(value, 10));
    assert.equal(descendantPids.length, 2);
    assert.equal(descendantPids.every((pid) => !isAlive(pid)), true);
    assert.equal(isAlive(sentinel.pid), true);
  } finally {
    if (sentinel.pid && isAlive(sentinel.pid)) {
      if (process.platform === "win32") sentinel.kill("SIGKILL");
      else process.kill(-sentinel.pid, "SIGKILL");
    }
  }
});

for (const [name, terminal, reason] of [
  ["crash", 'process.kill(process.pid, "SIGKILL");', "terminated"],
  ["timeout", "setInterval(() => {}, 1000);", "timeout"],
  ["leader-exit", "process.exit(23);", "failed"],
] as const) {
  test(`schema generator ${name} reaps its descendant and preserves an unrelated sentinel`, async () => {
    const root = await mkdtemp(join(tmpdir(), `projectos-generator-${name}-`));
    const executable = join(root, "codex");
    const descendantPidPath = join(root, "descendant-pid.txt");
    const script = `#!${process.execPath}\n` +
      `import { spawn } from "node:child_process";\n` +
      `import { writeFileSync } from "node:fs";\n` +
      `const descendant = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], { stdio: "ignore" });\n` +
      `writeFileSync(${JSON.stringify(descendantPidPath)}, String(descendant.pid), { mode: 0o600 });\n` +
      `descendant.unref();\n` +
      `${terminal}\n`;
    await writeFile(executable, script, { mode: 0o500 });
    await chmod(executable, 0o500);
    const sentinel = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
      detached: process.platform !== "win32",
      stdio: "ignore",
    });
    try {
      await assert.rejects(
        generateProtocolSchemas({
          executablePath: executable,
          stagingDirectory: join(root, "generated"),
          environment: { PATH: "/usr/bin:/bin" },
          timeoutMs: 500,
          shutdownStepMs: 100,
        }),
        (error: unknown) =>
          error instanceof ProtocolSchemaGenerationError &&
          error.reason === reason &&
          error.ownedProcessGroupReaped,
      );
      const descendantPid = Number.parseInt(await readFile(descendantPidPath, "utf8"), 10);
      assert.equal(await stopsWithin(descendantPid, 500), true);
      assert.equal(isAlive(sentinel.pid), true);
    } finally {
      if (sentinel.pid && isAlive(sentinel.pid)) {
        if (process.platform === "win32") sentinel.kill("SIGKILL");
        else process.kill(-sentinel.pid, "SIGKILL");
      }
    }
  });
}

function manifestFixture(
  json: Awaited<ReturnType<typeof collectProtocolSchemaBundle>>,
  typescript: Awaited<ReturnType<typeof collectProtocolSchemaBundle>>,
): SupportedRuntimeManifest {
  return {
    formatVersion: 1,
    manifestId: "projectos-codex-spike-darwin-arm64-0.145.0",
    runtime: {
      build: "codex-cli 0.145.0",
      platform: "darwin",
      architecture: "arm64",
      binaryContentSha256: "a".repeat(64),
    },
    generation: {
      jsonArgv: ["app-server", "generate-json-schema", "--out", "$JSON_OUT"],
      typescriptArgv: ["app-server", "generate-ts", "--out", "$TS_OUT"],
      digestAlgorithm: PROTOCOL_DIGEST_ALGORITHM,
    },
    schemas: { json, typescript },
    requiredMethods: {
      clientRequests: ["account/read", "initialize", "thread/start"],
      clientNotifications: ["initialized"],
      serverNotifications: ["error", "thread/started"],
      serverRequests: ["item/tool/call"],
      recognizedForbidden: ["item/tool/call"],
    },
    enabledDispatch: { clientRequests: ["initialize"], clientNotifications: ["initialized"] },
  };
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
