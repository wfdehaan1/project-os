import assert from "node:assert/strict";
import { mkdtemp, readdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import type { AiProviderPort, RuntimeHealthResult } from "../src/core/ai-provider-port.ts";
import { main, parseArguments } from "../src/cli.ts";

test("protocol validation CLI accepts only an explicit path and one bounded restart", () => {
  assert.deepEqual(parseArguments(["protocol-validate"]), {});
  assert.deepEqual(parseArguments(["protocol-validate", "--path", "/controlled/bin", "--restart"]), {
    path: "/controlled/bin",
    restart: true,
  });
  assert.deepEqual(parseArguments(["allowance-validate", "--path", "/controlled/bin"]), { allowance: true, path: "/controlled/bin" });
  assert.deepEqual(parseArguments(["structured-output-validate", "--job-id", "validation-only"]), { structuredOutput: true, jobId: "validation-only" });
  assert.deepEqual(parseArguments(["conversation-ownership-validate"]), { ownership: true });
  assert.deepEqual(parseArguments(["provider-cleanup-validate"]), { providerCleanup: true });
  assert.deepEqual(parseArguments(["--path", "/controlled/bin"]), { path: "/controlled/bin" });
  for (const arguments_ of [
    ["unknown"],
    ["protocol-validate", "--path"],
    ["protocol-validate", "--restart", "value"],
    ["protocol-validate", "--restart", "--restart"],
    ["protocol-validate", "--path", "/first", "--path", "/second"],
    ["structured-output-validate"],
    ["structured-output-validate", "--job-id", "../../outside"],
    ["conversation-ownership-validate", "--path", "/ignored"],
    ["provider-cleanup-validate", "--path", "/ignored"],
  ]) {
    assert.throws(() => parseArguments(arguments_));
  }
});

test("provider cleanup CLI is offline, writes a reject gate record, and never constructs a provider", async () => {
  const writes = { stdout: "", stderr: "" }; const evidenceRoot = await mkdtemp(join(tmpdir(), "projectos-cleanup-cli-"));
  const exitCode = await main(["provider-cleanup-validate"], { provider: { validateRuntime: async () => { throw new Error("provider must not be called"); } }, providerCleanupEvidenceRoot: evidenceRoot, stdout: { write: (value) => { writes.stdout += String(value); return true; } }, stderr: { write: (value) => { writes.stderr += String(value); return true; } } });
  assert.equal(exitCode, 0); assert.match(writes.stdout, /offline_provider_cleanup_validation/u); assert.match(writes.stdout, /"reject"/u); assert.equal(writes.stderr, "");
  assert.equal((await readdir(evidenceRoot)).filter((name) => name.endsWith("-provider-cleanup")).length, 1);
});

test("conversation ownership CLI is offline and never constructs a provider", async () => {
  const writes = { stdout: "", stderr: "" };
  const evidenceRoot = await mkdtemp(join(tmpdir(), "projectos-ownership-cli-"));
  const exitCode = await main(["conversation-ownership-validate"], {
    provider: { validateRuntime: async () => { throw new Error("provider must not be called"); } },
    ownershipEvidenceRoot: evidenceRoot,
    stdout: { write: (value) => { writes.stdout += String(value); return true; } },
    stderr: { write: (value) => { writes.stderr += String(value); return true; } },
  });
  assert.equal(exitCode, 0); assert.match(writes.stdout, /offline_ownership_validation/u); assert.equal(writes.stderr, "");
  assert.equal((await readdir(evidenceRoot)).filter((name) => name.endsWith("-conversation-ownership")).length, 1);
});

test("structured-output CLI is a nonzero containment denial without a provider action", async () => {
  const writes = { stdout: "", stderr: "" };
  const provider: AiProviderPort = { validateRuntime: async () => { throw new Error("unexpected runtime call"); }, validateStructuredOutput: async () => ({ ok: false, code: "containment_attestation_required", correlationId: "structured-cli-denied", stopCondition: "containment_attestation_required", providerActionEnabled: false, canonicalStateOperationEnabled: false }) };
  const exitCode = await main(["structured-output-validate", "--job-id", "validation-only"], { provider, stdout: { write: (value) => { writes.stdout += String(value); return true; } }, stderr: { write: (value) => { writes.stderr += String(value); return true; } } });
  assert.equal(exitCode, 1); assert.match(writes.stdout, /containment_attestation_required/u); assert.equal(writes.stderr, "");
});

test("containment CLI is a nonzero reject when no preventive boundary is available", async () => {
  const writes = { stdout: "", stderr: "" };
  const provider: AiProviderPort = {
    validateRuntime: async () => { throw new Error("unexpected runtime call"); },
    validatePreventiveExecutionContainment: async () => ({
      ok: false,
      code: "containment_boundary_unavailable",
      correlationId: "containment-cli-denied",
      stopCondition: "containment_boundary_unavailable",
      providerActionEnabled: false,
      canonicalStateOperationEnabled: false,
    }),
  };
  const exitCode = await main(["containment-validate", "--job-id", "containment-only"], {
    provider,
    stdout: { write: (value) => { writes.stdout += String(value); return true; } },
    stderr: { write: (value) => { writes.stderr += String(value); return true; } },
  });
  assert.equal(exitCode, 1);
  assert.match(writes.stdout, /containment_boundary_unavailable/u);
  assert.equal(writes.stderr, "");
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
