import assert from "node:assert/strict";
import test from "node:test";

import type { AiProviderPort, RuntimeHealthResult } from "../src/core/ai-provider-port.ts";
import { main, parseArguments } from "../src/cli.ts";

test("protocol validation CLI accepts only an explicit path and one bounded restart", () => {
  assert.deepEqual(parseArguments(["protocol-validate"]), {});
  assert.deepEqual(parseArguments(["protocol-validate", "--path", "/controlled/bin", "--restart"]), {
    path: "/controlled/bin",
    restart: true,
  });
  assert.deepEqual(parseArguments(["--path", "/controlled/bin"]), { path: "/controlled/bin" });
  for (const arguments_ of [
    ["unknown"],
    ["protocol-validate", "--path"],
    ["protocol-validate", "--restart", "value"],
    ["protocol-validate", "--restart", "--restart"],
    ["protocol-validate", "--path", "/first", "--path", "/second"],
  ]) {
    assert.throws(() => parseArguments(arguments_));
  }
});

for (const [result, expectedExit] of [
  [{
    ok: true,
    correlationId: "corr-cli-success",
    lifecycle: ["undiscovered", "stopped"],
    runtimeVersion: "codex-cli 9.8.7",
    compatibilityStatus: "compatible",
    attemptId: "attempt-cli-success",
    attemptCount: 1,
    manifestId: "manifest-cli",
    schemaDigests: { jsonSha256: "a".repeat(64), typescriptSha256: "b".repeat(64) },
    shutdownOutcome: "clean_exit",
    providerActionEnabled: false,
    canonicalStateOperationEnabled: false,
  }, 0],
  [{
    ok: false,
    code: "runtime_not_found",
    correlationId: "corr-cli-failure",
    remediation: { action: "install_runtime", reference: "codex-cli" },
    providerActionEnabled: false,
    canonicalStateOperationEnabled: false,
  }, 1],
] as const satisfies readonly (readonly [RuntimeHealthResult, number])[]) {
  test(`protocol CLI returns ${expectedExit} and writes only the safe result`, async () => {
    const writes = { stdout: "", stderr: "" };
    const provider: AiProviderPort = { validateRuntime: async () => result };
    const exitCode = await main(["protocol-validate"], {
      provider,
      stdout: { write: (value) => { writes.stdout += String(value); return true; } },
      stderr: { write: (value) => { writes.stderr += String(value); return true; } },
    });
    assert.equal(exitCode, expectedExit);
    assert.deepEqual(JSON.parse(writes.stdout), result);
    assert.equal(writes.stderr, "");
    assert.doesNotMatch(writes.stdout, /private|secret|stderr/iu);
  });
}

test("protocol CLI returns 2 and writes usage to stderr for invalid arguments", async () => {
  const writes = { stdout: "", stderr: "" };
  const exitCode = await main(["protocol-validate", "--unknown"], {
    stdout: { write: (value) => { writes.stdout += String(value); return true; } },
    stderr: { write: (value) => { writes.stderr += String(value); return true; } },
  });
  assert.equal(exitCode, 2);
  assert.equal(writes.stdout, "");
  assert.match(writes.stderr, /^Usage:/u);
});

test("authentication CLI exits nonzero for normalized non-success validation", async () => {
  const writes = { stdout: "", stderr: "" };
  const provider: AiProviderPort = {
    validateRuntime: async () => { throw new Error("unexpected runtime call"); },
    validateAuthentication: async () => ({
      ok: false,
      code: "authentication_cancelled",
      correlationId: "auth-cli-cancelled",
      remediation: { action: "retry_validation", reference: "cancelled" },
      providerActionEnabled: false,
      canonicalStateOperationEnabled: false,
    }),
  };
  const exitCode = await main(["auth-validate", "--interactive"], {
    provider,
    stdout: { write: (value) => { writes.stdout += String(value); return true; } },
    stderr: { write: (value) => { writes.stderr += String(value); return true; } },
  });
  assert.equal(exitCode, 1);
  assert.match(writes.stdout, /authentication_cancelled/u);
  assert.equal(writes.stderr, "");
});
