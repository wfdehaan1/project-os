import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { createExecutableSnapshot } from "../../src/adapters/codex/executable-snapshot.ts";
import {
  PROTOCOL_DIGEST_ALGORITHM,
  extractGeneratedProtocolMethods,
  type SupportedRuntimeManifest,
} from "../../src/adapters/codex/protocol-contract.ts";
import { generateProtocolSchemas } from "../../src/adapters/codex/protocol-schema-generator.ts";
import { createIsolatedRuntimeProfile } from "../../src/adapters/codex/runtime-profile.ts";
import { createFakeCodexRuntime, type FakeCodexBehavior } from "./fake-codex-runtime.ts";

export async function createFakeRuntimeManifest(behavior: FakeCodexBehavior, marker?: string) {
  const root = await mkdtemp(join(tmpdir(), "projectos-fake-runtime-manifest-"));
  const fake = await createFakeCodexRuntime(join(root, "bin"), behavior, marker);
  const profile = await createIsolatedRuntimeProfile({ baseDirectory: join(root, "manifest-runs") });
  const snapshot = await createExecutableSnapshot({
    sourcePath: fake.executablePath,
    instanceDirectory: profile.runtimeRoot,
  });
  const generated = await generateProtocolSchemas({
    executablePath: snapshot.executablePath,
    stagingDirectory: join(profile.runtimeRoot, "manifest-generated"),
    environment: profile.childEnvironment,
    timeoutMs: 2_000,
    shutdownStepMs: 50,
  });
  const methods = await extractGeneratedProtocolMethods(generated.jsonDirectory);
  const manifest: SupportedRuntimeManifest = {
    formatVersion: 1,
    manifestId: "test-runtime-manifest",
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
    schemas: { json: generated.jsonBundle, typescript: generated.typescriptBundle },
    requiredMethods: { ...methods, recognizedForbidden: ["item/tool/call"] },
    enabledDispatch: { clientRequests: ["initialize"], clientNotifications: ["initialized"] },
    authentication: {
      clientRequests: ["account/login/cancel", "account/login/start", "account/logout", "account/read"],
      serverNotifications: ["account/login/completed", "account/updated"],
    },
    allowance: {
      clientRequests: ["account/rateLimits/read"],
      serverNotifications: ["account/rateLimits/updated"],
    },
  };
  const manifestPath = join(root, "manifest.json");
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  return { root, fake, manifestPath };
}
