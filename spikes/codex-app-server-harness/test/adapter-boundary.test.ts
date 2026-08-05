import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import test from "node:test";

const coreFiles = [
  "ai-provider-port.ts",
  "conversation-ownership.ts",
  "failures.ts",
  "lifecycle.ts",
  "project-export.ts",
  "project-restore.ts",
] as const;

test("public provider modules do not import or expose Codex protocol types", async () => {
  for (const file of coreFiles) {
    const source = await readFile(new URL(`../src/core/${file}`, import.meta.url), "utf8");
    assert.doesNotMatch(source, /adapters\/codex|protocol\.ts|CodexInitialize|Jsonl/iu, file);
  }
});

test("portable ownership and restore remain pure core contracts", async () => {
  for (const file of ["conversation-ownership.ts", "project-export.ts", "project-restore.ts"] as const) {
    const source = await readFile(new URL(`../src/core/${file}`, import.meta.url), "utf8");
    assert.doesNotMatch(source, /AiProviderPort|adapters\/codex|CodexAppServer|thread\/(?:start|resume)|turn\/start/iu, file);
  }
});

test("Codex adapter has no domain repository access or production action methods", async () => {
  const sources = await sourceTree();
  const combined = sources.filter(({ path }) => path !== "adapters/codex/protocol-contract.ts").map(({ source }) => source).join("\n");
  assert.doesNotMatch(
    combined,
    /CanonicalStateRepository|ConversationRepository|ChangeProposalRepository|ExportRepository|DeletionRepository/iu,
  );
  assert.doesNotMatch(combined, /thread\/(start|resume)|turn\/start|model\/call/iu);
  const contract = sources.find(({ path }) => path === "adapters/codex/protocol-contract.ts")?.source ?? "";
  assert.match(contract, /createStructuredOutputProtocolBoundary/iu);
  assert.match(contract, /exactArray\(value\.clientRequests, \["thread\/start", "turn\/start"\]\)/u);
});

test("the only App Server spawn path requires a validated opaque capability", async () => {
  const sources = await sourceTree();
  const supervisor = await readFile(
    new URL("../src/adapters/codex/app-server-supervisor.ts", import.meta.url),
    "utf8",
  );
  const contract = await readFile(
    new URL("../src/adapters/codex/protocol-contract.ts", import.meta.url),
    "utf8",
  );
  const compatibility = await readFile(
    new URL("../src/adapters/codex/runtime-compatibility.ts", import.meta.url),
    "utf8",
  );
  const appServerSpawnSources = sources.filter(({ source }) =>
    /\[\s*"app-server"\s*,\s*"--stdio"\s*,\s*"--strict-config"\s*\]/u.test(source),
  );
  assert.deepEqual(
    appServerSpawnSources.map(({ path }) => path),
    ["adapters/codex/app-server-supervisor.ts"],
  );
  assert.equal(
    sources.reduce(
      (count, { source }) =>
        count + (source.match(/"app-server"\s*,\s*"--stdio"\s*,\s*"--strict-config"/gu)?.length ?? 0),
      0,
    ),
    1,
  );
  assert.match(supervisor, /authorizeCompatibleAppServerSpawn\(\s*options\.compatibility/iu);
  assert.doesNotMatch(supervisor, /export\s+(?:async\s+)?function\s+spawnOwned/iu);
  assert.doesNotMatch(supervisor, /readonly executablePath:|readonly protocolBoundary:/iu);
  assert.match(compatibility, /const compatibilityCapabilityBrand/iu);
  assert.doesNotMatch(compatibility, /export\s+const\s+compatibilityCapabilityBrand/iu);
  assert.doesNotMatch(compatibility, /export\s+function\s+mintCompatibilityCapability/iu);
  assert.doesNotMatch(contract, /validateProtocolCompatibility|mintCompatibilityCapability/iu);
});

async function sourceTree(): Promise<readonly { path: string; source: string }[]> {
  const root = new URL("../src/", import.meta.url);
  const paths = (await readdir(root, { recursive: true }))
    .filter((path) => path.endsWith(".ts"))
    .sort();
  return Promise.all(
    paths.map(async (path) => ({
      path,
      source: await readFile(new URL(path, root), "utf8"),
    })),
  );
}
