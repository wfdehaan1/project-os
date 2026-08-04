import { rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

import { createExecutableSnapshot } from "../../src/adapters/codex/executable-snapshot.ts";
import {
  extractGeneratedProtocolMethods,
  PROTOCOL_DIGEST_ALGORITHM,
  type SupportedRuntimeManifest,
} from "../../src/adapters/codex/protocol-contract.ts";
import { generateProtocolSchemas } from "../../src/adapters/codex/protocol-schema-generator.ts";
import { validateSnapshotCompatibility } from "../../src/adapters/codex/runtime-compatibility.ts";
import { createIsolatedRuntimeProfile } from "../../src/adapters/codex/runtime-profile.ts";
import type { createFakeCodexRuntime } from "./fake-codex-runtime.ts";

type FakeCodexRuntime = Awaited<ReturnType<typeof createFakeCodexRuntime>>;

export async function fakeCompatibilityCapability(
  fake: FakeCodexRuntime,
  root: string,
  attemptId = "attempt-test",
) {
  const profile = await createIsolatedRuntimeProfile({
    baseDirectory: join(root, "compatibility-runs"),
  });
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
  const manifest: SupportedRuntimeManifest = {
    formatVersion: 1,
    manifestId: "test-manifest",
    runtime: {
      build: "codex-cli 9.8.7",
      platform: process.platform,
      architecture: process.arch,
      binaryContentSha256: snapshot.binaryContentSha256,
    },
    generation: {
      jsonArgv: ["app-server", "generate-json-schema", "--out", "$JSON_OUT"],
      typescriptArgv: ["app-server", "generate-ts", "--out", "$TS_OUT"],
      digestAlgorithm: PROTOCOL_DIGEST_ALGORITHM,
    },
    schemas: {
      json: generated.jsonBundle,
      typescript: generated.typescriptBundle,
    },
    requiredMethods: {
      ...methods,
      recognizedForbidden: ["item/tool/call"],
    },
    enabledDispatch: {
      clientRequests: ["initialize"],
      clientNotifications: ["initialized"],
    },
  };
  const manifestPath = join(profile.runtimeRoot, "test-manifest.json");
  await writeFile(manifestPath, `${JSON.stringify(manifest)}\n`, { mode: 0o600 });
  const compatibility = await validateSnapshotCompatibility({
    attemptId,
    snapshot,
    manifestPath,
    environment: profile.childEnvironment,
    workingDirectory: profile.workingDirectory,
    stagingDirectory: join(profile.runtimeRoot, "validated-generated"),
    versionTimeoutMs: 1_500,
    generatorTimeoutMs: 1_500,
    generatorShutdownStepMs: 50,
  });
  if (!compatibility.ok) {
    throw new Error(`test compatibility fixture failed: ${compatibility.reason}`);
  }
  await rm(fake.transcriptPath, { force: true });
  return Object.freeze({
    attemptId,
    compatibility: compatibility.capability,
    workingDirectory: profile.workingDirectory,
    environment: profile.childEnvironment,
    snapshotExecutablePath: snapshot.executablePath,
    snapshotDirectory: snapshot.snapshotDirectory,
  });
}
