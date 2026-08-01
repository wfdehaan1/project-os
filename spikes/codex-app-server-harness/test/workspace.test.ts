import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const requiredFiles = [
  ".gitignore",
  ".nvmrc",
  "README.md",
  "package-lock.json",
  "src/cli.ts",
  "tsconfig.json",
] as const;

test("workspace pins the disposable harness contract", async () => {
  for (const path of requiredFiles) {
    await access(new URL(`../${path}`, import.meta.url));
  }

  const packageJson = JSON.parse(
    await readFile(new URL("../package.json", import.meta.url), "utf8"),
  ) as { engines: { node: string }; scripts: Record<string, string> };

  assert.equal(packageJson.engines.node, "24.18.1");
  assert.match(packageJson.scripts.typecheck ?? "", /tsc --noEmit/);
  assert.ok(packageJson.scripts.test);
  assert.ok(packageJson.scripts["test:live"]);
  assert.ok(packageJson.scripts["validate:full"]);
});
