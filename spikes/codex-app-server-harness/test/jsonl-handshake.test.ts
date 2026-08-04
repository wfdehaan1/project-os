import assert from "node:assert/strict";
import { chmod, mkdtemp, readFile, unlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import test from "node:test";

import {
  superviseCodexAppServer,
  type AppServerSupervisorResult,
} from "../src/adapters/codex/app-server-supervisor.ts";
import {
  JsonlRpcConnection,
  type StructuralProtocolTranscriptEntry,
} from "../src/adapters/codex/jsonl-rpc-connection.ts";
import type { ProtocolBoundary } from "../src/adapters/codex/protocol-contract.ts";
import { createFakeCodexRuntime } from "./fixtures/fake-codex-runtime.ts";
import { fakeCompatibilityCapability } from "./fixtures/fake-compatibility-capability.ts";

function compatibility(
  fake: Awaited<ReturnType<typeof createFakeCodexRuntime>>,
  root: string,
  attemptId: string,
) {
  return fakeCompatibilityCapability(fake, root, attemptId);
}

test("supervisor uses strict stdio args and initialize then initialized JSONL order", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-handshake-"));
  const fake = await createFakeCodexRuntime(root, "success");
  const result = await superviseCodexAppServer({
    ...(await compatibility(fake, root, "attempt-handshake")),
    workingDirectory: root,
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 1_500,
    shutdownTimeoutMs: 500,
    correlationId: "corr-handshake",
  });
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.shutdownOutcome, "clean_exit");
  assert.equal(result.processGroupReaped, true);
  assert.deepEqual(result.lifecycle, [
    "undiscovered",
    "discovered",
    "starting",
    "initializing",
    "initialized",
    "stopping",
    "stopped",
  ]);
  assert.deepEqual(
    result.transcript.map(({ direction, method, requestIdClass, classification }) => ({
      direction,
      method,
      requestIdClass,
      classification,
    })),
    [
      {
        direction: "outbound_request",
        method: "initialize",
        requestIdClass: "initialize",
        classification: "sent_experimental_api_disabled",
      },
      {
        direction: "inbound_response",
        method: "initialize",
        requestIdClass: "initialize",
        classification: "matched",
      },
      {
        direction: "outbound_notification",
        method: "initialized",
        requestIdClass: "none",
        classification: "sent",
      },
    ],
  );
  assert.equal(JSON.stringify(result.transcript).includes("params"), false);

  const lines = (await readFile(fake.transcriptPath, "utf8"))
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line) as Record<string, unknown>);
  assert.deepEqual(lines[0]?.argv, ["app-server", "--stdio", "--strict-config"]);
  assert.equal(Number.isSafeInteger(lines[0]?.pid), true);
  assert.deepEqual(lines[1], {
    id: 1,
    method: "initialize",
    params: {
      clientInfo: { name: "ProjectOS", title: "ProjectOS validation harness", version: "0.1.0" },
      capabilities: { experimentalApi: false },
    },
  });
  assert.deepEqual(lines[2], { method: "initialized" });
});

test("supervisor ignores an unrelated response ID and waits for the matching response", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-matching-id-"));
  const fake = await createFakeCodexRuntime(root, "wrong-id-then-match");
  const result = await superviseCodexAppServer({
    ...(await compatibility(fake, root, "attempt-matching-id")),
    workingDirectory: root,
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
    correlationId: "corr-matching-id",
  });
  assert.equal(result.ok, true);
});

test("supervisor rejects duplicate matching initialize responses without sending initialized twice", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-duplicate-match-"));
  const fake = await createFakeCodexRuntime(root, "duplicate-match");
  const result = await superviseCodexAppServer({
    ...(await compatibility(fake, root, "attempt-duplicate-match")),
    workingDirectory: root,
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
    correlationId: "corr-duplicate-match",
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "malformed_handshake_response");

  const initializedCount = (await readFile(fake.transcriptPath, "utf8"))
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line) as Record<string, unknown>)
    .filter((line) => line.method === "initialized").length;
  assert.equal(initializedCount, 1);
});

for (const [behavior, code] of [
  ["reject", "initialization_rejected"],
  ["malformed", "malformed_handshake_response"],
  ["eof", "unexpected_exit_or_eof"],
  ["timeout", "initialization_timeout"],
  ["unexpected-exit", "unexpected_exit_or_eof"],
] as const) {
  test(`supervisor maps ${behavior} without starting provider work`, async () => {
    const root = await mkdtemp(join(tmpdir(), `projectos-${behavior}-`));
    const fake = await createFakeCodexRuntime(root, behavior);
    const result = await superviseCodexAppServer({
      ...(await compatibility(fake, root, `attempt-${behavior}`)),
      workingDirectory: root,
      environment: { PATH: "/usr/bin:/bin" },
      initializationTimeoutMs: 500,
      shutdownTimeoutMs: 30,
      correlationId: `corr-${behavior}`,
    });
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.code, code);
    assert.equal(result.providerActionEnabled, false);
    assert.equal(result.canonicalStateOperationEnabled, false);
    assert.match(result.diagnosticReference ?? "", /^protocol-[a-f0-9]{24}$/u);
    assert.equal(result.processGroupReaped, true);
    const pid = Number.parseInt(await readFile(fake.pidPath, "utf8"), 10);
    assert.equal(isAlive(pid), false);
    if (behavior === "timeout") assert.equal(result.shutdownOutcome, "graceful_termination");
    if (behavior === "malformed") assert.equal(result.shutdownOutcome, "graceful_termination");
  });
}

test("spawn failure is distinct", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-spawn-failure-"));
  const fake = await createFakeCodexRuntime(root, "success");
  const validated = await compatibility(fake, root, "attempt-spawn");
  await chmod(validated.snapshotDirectory, 0o700);
  await unlink(validated.snapshotExecutablePath);
  const result = await superviseCodexAppServer({
    ...validated,
    initializationTimeoutMs: 30,
    shutdownTimeoutMs: 30,
    correlationId: "corr-spawn",
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "spawn_failed");
});

test("supervisor rejects a forged compatibility object before App Server spawn", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-no-capability-"));
  const fake = await createFakeCodexRuntime(root, "success");
  const forged = await compatibility(fake, root, "attempt-no-capability");
  const result = await superviseCodexAppServer({
    ...forged,
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
    correlationId: "corr-no-capability",
    compatibility: {} as never,
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "protocol_compatibility_required");
  await assert.rejects(readFile(fake.transcriptPath, "utf8"));
});

test("validated compatibility capability authorizes exactly one bound App Server spawn", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-single-use-capability-"));
  const fake = await createFakeCodexRuntime(root, "success");
  const validated = await compatibility(fake, root, "attempt-single-use");
  const options = {
    ...validated,
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
    correlationId: "corr-single-use",
  };
  const first = await superviseCodexAppServer(options);
  assert.equal(first.ok, true);
  const second = await superviseCodexAppServer(options);
  assert.equal(second.ok, false);
  if (!second.ok) assert.equal(second.code, "protocol_compatibility_required");
  const transcript = await readFile(fake.transcriptPath, "utf8");
  assert.equal(transcript.match(/"app-server","--stdio","--strict-config"/gu)?.length, 1);
});

test("recognized semantic notifications remain structural and do not make the runtime ready", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-semantic-notification-"));
  const fake = await createFakeCodexRuntime(root, "semantic-notification");
  const result = await superviseCodexAppServer({
    ...(await compatibility(fake, root, "attempt-semantic-notification")),
    workingDirectory: root,
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 500,
    shutdownTimeoutMs: 100,
    correlationId: "corr-semantic-notification",
  });
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(
    result.transcript.some(
      (entry) => entry.method === "warning" && entry.classification === "semantic",
    ),
    true,
  );
  assert.equal(JSON.stringify(result.transcript).includes("not-persisted"), false);
});

test("a semantic notification alone cannot make the runtime ready", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-semantic-notification-only-"));
  const fake = await createFakeCodexRuntime(root, "semantic-notification-only");
  const result = await superviseCodexAppServer({
    ...(await compatibility(fake, root, "attempt-semantic-notification-only")),
    workingDirectory: root,
    environment: { PATH: "/usr/bin:/bin" },
    initializationTimeoutMs: 100,
    shutdownTimeoutMs: 100,
    correlationId: "corr-semantic-notification-only",
  });
  await assertTerminalFailure(result, fake, "initialization_timeout");
  assert.equal(
    result.transcript.some(
      (entry) => entry.method === "warning" && entry.classification === "semantic",
    ),
    true,
  );
  assert.equal(result.transcript.some((entry) => entry.classification === "matched"), false);
});

for (const behavior of [
  "forbidden-request",
  "semantic-request",
  "unknown-method",
  "request-before-initialize",
] as const) {
  test(`${behavior} fails closed without an answer or initialized notification`, async () => {
    const root = await mkdtemp(join(tmpdir(), `projectos-${behavior}-`));
    const fake = await createFakeCodexRuntime(root, behavior);
    const result = await superviseCodexAppServer({
      ...(await compatibility(fake, root, `attempt-${behavior}`)),
      workingDirectory: root,
      environment: { PATH: "/usr/bin:/bin" },
      initializationTimeoutMs: 500,
      shutdownTimeoutMs: 100,
      correlationId: `corr-${behavior}`,
    });
    await assertTerminalFailure(result, fake, "unsupported_dispatch");
    if (result.ok) return;
    assert.equal(
      result.transcript.some((entry) =>
        ["forbidden_side_effect", "unknown"].includes(entry.classification),
      ),
      true,
    );
    assert.equal(JSON.stringify(result.transcript).includes("not-persisted"), false);
    const transcript = (await readFile(fake.transcriptPath, "utf8"))
      .trim()
      .split("\n")
      .map((line) => JSON.parse(line) as Record<string, unknown>);
    assert.equal(transcript.some((message) => message.method === "initialized"), false);
    assert.equal(
      transcript.some((message) => message.id === 77 || message.id === 78 || message.id === 88),
      false,
    );
  });
}

test("initialize write failure is absent from the outbound transcript", async () => {
  const stdout = new PassThrough();
  const child = Object.assign(new EventEmitter(), {
    stdout,
    stderr: new PassThrough(),
    stdin: {
      destroyed: false,
      end() {},
      write(
        _value: string,
        _encoding: string,
        callback: (error?: Error | null) => void,
      ) {
        queueMicrotask(() => callback(new Error("synthetic write failure")));
        return false;
      },
    },
    exitCode: null,
    signalCode: null,
  });
  const transcript: StructuralProtocolTranscriptEntry[] = [];
  const boundary: ProtocolBoundary = {
    enabledClientRequests: ["initialize"],
    enabledClientNotifications: ["initialized"],
    assertClientRequest(method) {
      if (method !== "initialize") throw new Error("unsupported_dispatch");
    },
    assertClientNotification(method) {
      if (method !== "initialized") throw new Error("unsupported_dispatch");
    },
    classifyInbound() {
      return "unknown";
    },
  };
  const connection = new JsonlRpcConnection(child as never, {
    attemptId: "attempt-write-failure",
    protocolBoundary: boundary,
    transcriptSink: (entry) => transcript.push(entry),
  });

  await assert.rejects(connection.initialize(100), /unexpected_exit_or_eof/u);
  assert.deepEqual(transcript, []);
  stdout.destroy();
});

test("initialized write failure is absent from the outbound transcript", async () => {
  const stdout = new PassThrough();
  let writeCount = 0;
  const child = mockChild(stdout, (_value, callback) => {
    writeCount += 1;
    queueMicrotask(() => {
      if (writeCount === 1) {
        callback();
        stdout.write(`${JSON.stringify({ id: 1, result: { userAgent: "fixture" } })}\n`);
      } else {
        callback(new Error("synthetic initialized write failure"));
      }
    });
    return false;
  });
  const transcript: StructuralProtocolTranscriptEntry[] = [];
  const connection = new JsonlRpcConnection(child as never, {
    attemptId: "attempt-initialized-write-failure",
    protocolBoundary: testBoundary(),
    transcriptSink: (entry) => transcript.push(entry),
  });

  await assert.rejects(connection.initialize(100), /synthetic initialized write failure/u);
  assert.deepEqual(
    transcript.map(({ direction, method }) => ({ direction, method })),
    [
      { direction: "outbound_request", method: "initialize" },
      { direction: "inbound_response", method: "initialize" },
    ],
  );
  stdout.destroy();
});

test("successful callbacks remain transcript-truthful after stream backpressure", async () => {
  const stdout = new PassThrough();
  let writeCount = 0;
  const child = mockChild(stdout, (_value, callback) => {
    writeCount += 1;
    queueMicrotask(() => {
      callback();
      if (writeCount === 1) {
        stdout.write(`${JSON.stringify({ id: 1, result: { userAgent: "fixture" } })}\n`);
      }
    });
    return false;
  });
  const transcript: StructuralProtocolTranscriptEntry[] = [];
  const connection = new JsonlRpcConnection(child as never, {
    attemptId: "attempt-backpressure-success",
    protocolBoundary: testBoundary(),
    transcriptSink: (entry) => transcript.push(entry),
  });

  await connection.initialize(100);
  assert.equal(writeCount, 2);
  assert.deepEqual(
    transcript.map(({ direction, method, classification }) => ({ direction, method, classification })),
    [
      { direction: "outbound_request", method: "initialize", classification: "sent_experimental_api_disabled" },
      { direction: "inbound_response", method: "initialize", classification: "matched" },
      { direction: "outbound_notification", method: "initialized", classification: "sent" },
    ],
  );
  stdout.destroy();
});

for (const [behavior, code] of [
  ["oversized", "malformed_handshake_response"],
  ["repeated-initialize", "unsupported_dispatch"],
  ["wrong-id-only", "initialization_timeout"],
] as const) {
  test(`${behavior} reaches a bounded deterministic terminal failure`, async () => {
    const root = await mkdtemp(join(tmpdir(), `projectos-${behavior}-`));
    const fake = await createFakeCodexRuntime(root, behavior);
    const result = await superviseCodexAppServer({
      ...(await compatibility(fake, root, `attempt-${behavior}`)),
      workingDirectory: root,
      environment: { PATH: "/usr/bin:/bin" },
      initializationTimeoutMs: 500,
      shutdownTimeoutMs: 100,
      correlationId: `corr-${behavior}`,
    });
    await assertTerminalFailure(result, fake, code);
  });
}

async function assertTerminalFailure(
  result: AppServerSupervisorResult,
  fake: Awaited<ReturnType<typeof createFakeCodexRuntime>>,
  code: Extract<AppServerSupervisorResult, { ok: false }>["code"],
): Promise<void> {
  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.code, code);
  assert.equal(result.providerActionEnabled, false);
  assert.equal(result.canonicalStateOperationEnabled, false);
  assert.match(result.diagnosticReference ?? "", /^protocol-[a-f0-9]{24}$/u);
  assert.notEqual(result.shutdownOutcome, "not_started");
  assert.equal(result.processGroupReaped, true);
  assert.equal(result.lifecycle.at(-1), "failed");
  const pid = Number.parseInt(await readFile(fake.pidPath, "utf8"), 10);
  assert.equal(await stopsWithin(pid, 500), true);
}

function mockChild(
  stdout: PassThrough,
  write: (value: string, callback: (error?: Error | null) => void) => boolean,
) {
  return Object.assign(new EventEmitter(), {
    stdout,
    stderr: new PassThrough(),
    stdin: {
      destroyed: false,
      end() {},
      write(
        value: string,
        _encoding: string,
        callback: (error?: Error | null) => void,
      ) {
        return write(value, callback);
      },
    },
    exitCode: null,
    signalCode: null,
  });
}

function testBoundary(): ProtocolBoundary {
  return {
    enabledClientRequests: ["initialize"],
    enabledClientNotifications: ["initialized"],
    assertClientRequest(method) {
      if (method !== "initialize") throw new Error("unsupported_dispatch");
    },
    assertClientNotification(method) {
      if (method !== "initialized") throw new Error("unsupported_dispatch");
    },
    classifyInbound() {
      return "unknown";
    },
  };
}

function isAlive(pid: number): boolean {
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
