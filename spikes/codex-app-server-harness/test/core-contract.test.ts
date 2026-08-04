import assert from "node:assert/strict";
import test from "node:test";

import {
  FAILURE_CODES,
  createProviderFailure,
} from "../src/core/failures.ts";
import { LifecycleTracker } from "../src/core/lifecycle.ts";

test("lifecycle follows the explicit initialization and shutdown path", () => {
  const lifecycle = new LifecycleTracker();
  for (const phase of [
    "discovered",
    "starting",
    "initializing",
    "initialized",
    "stopping",
    "stopped",
  ] as const) {
    assert.equal(lifecycle.transition(phase), true);
  }
  assert.deepEqual(lifecycle.history, [
    "undiscovered",
    "discovered",
    "starting",
    "initializing",
    "initialized",
    "stopping",
    "stopped",
  ]);
});

test("terminal lifecycle states cannot be revived by late events", () => {
  const failed = new LifecycleTracker();
  assert.equal(failed.fail(), true);
  assert.equal(failed.transition("discovered"), false);
  assert.equal(failed.phase, "failed");

  const stopped = new LifecycleTracker();
  for (const phase of [
    "discovered",
    "starting",
    "initializing",
    "initialized",
    "stopping",
    "stopped",
  ] as const) {
    assert.equal(stopped.transition(phase), true);
  }
  assert.equal(stopped.fail(), false);
  assert.equal(stopped.transition("stopping"), false);
  assert.equal(stopped.phase, "stopped");
});

test("provider failures use every distinct stable story code and safe remediation metadata", () => {
  assert.deepEqual(FAILURE_CODES, [
    "runtime_not_found",
    "runtime_not_executable",
    "version_probe_failed",
    "runtime_snapshot_failed",
    "unsupported_runtime_build",
    "protocol_binary_mismatch",
    "schema_generation_failed",
    "invalid_protocol_manifest",
    "protocol_schema_mismatch",
    "missing_required_method",
    "unsupported_dispatch",
    "protocol_compatibility_required",
    "runtime_terminated_during_checking",
    "restart_failed",
    "spawn_failed",
    "initialization_rejected",
    "malformed_handshake_response",
    "initialization_timeout",
    "unexpected_exit_or_eof",
    "shutdown_timeout",
    "shutdown_failed",
    "isolation_failed",
    "evidence_write_failed",
    "authentication_unsupported",
    "authentication_timeout",
    "authentication_cancelled",
    "authentication_expired",
    "authentication_failed",
    "secure_storage_unavailable",
    "credential_ownership_rejected",
  ]);

  const failure = createProviderFailure({
    code: "runtime_not_found",
    correlationId: "corr-test",
    remediation: { action: "install_runtime", reference: "codex-cli" },
  });
  assert.equal(failure.correlationId, "corr-test");
  assert.equal(failure.providerActionEnabled, false);
  assert.equal(failure.canonicalStateOperationEnabled, false);
  assert.equal("message" in failure, false);
});
