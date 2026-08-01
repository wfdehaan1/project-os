import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const coreFiles = ["ai-provider-port.ts", "failures.ts", "lifecycle.ts"] as const;
const adapterFiles = [
  "app-server-supervisor.ts",
  "codex-app-server-adapter.ts",
  "executable-discovery.ts",
  "jsonl-rpc-connection.ts",
  "protocol.ts",
  "runtime-profile.ts",
] as const;

test("public provider modules do not import or expose Codex protocol types", async () => {
  for (const file of coreFiles) {
    const source = await readFile(new URL(`../src/core/${file}`, import.meta.url), "utf8");
    assert.doesNotMatch(source, /adapters\/codex|protocol\.ts|CodexInitialize|Jsonl/iu, file);
  }
});

test("Codex adapter has no domain repository access or production action methods", async () => {
  const sources = await Promise.all(
    adapterFiles.map((file) => readFile(new URL(`../src/adapters/codex/${file}`, import.meta.url), "utf8")),
  );
  const combined = sources.join("\n");
  assert.doesNotMatch(
    combined,
    /CanonicalStateRepository|ConversationRepository|ChangeProposalRepository|ExportRepository|DeletionRepository/iu,
  );
  assert.doesNotMatch(combined, /thread\/(start|resume)|turn\/start|model\/call/iu);
});
