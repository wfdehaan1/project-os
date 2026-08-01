import { createHash } from "node:crypto";
import {
  spawn,
  type ChildProcessWithoutNullStreams,
  type SpawnOptionsWithoutStdio,
} from "node:child_process";

import type { ShutdownOutcome } from "../../core/ai-provider-port.ts";
import {
  createProviderFailure,
  type ProviderFailure,
  type ProviderFailureCode,
} from "../../core/failures.ts";
import { LifecycleTracker, type LifecyclePhase } from "../../core/lifecycle.ts";
import { JsonlRpcConnection } from "./jsonl-rpc-connection.ts";
import { HandshakeProtocolError } from "./protocol.ts";

const STDERR_HASH_LIMIT = 64 * 1024;

export interface AppServerSupervisorOptions {
  readonly executablePath: string;
  readonly workingDirectory: string;
  readonly environment: Readonly<Record<string, string>>;
  readonly initializationTimeoutMs: number;
  readonly shutdownTimeoutMs: number;
  readonly correlationId: string;
  readonly postInitializeCheck?: () => void;
}

export interface AppServerSupervisorSuccess {
  readonly ok: true;
  readonly correlationId: string;
  readonly lifecycle: readonly LifecyclePhase[];
  readonly handshakeOutcome: "initialized";
  readonly shutdownOutcome: ShutdownOutcome;
  readonly childPid: number;
  readonly stderrFingerprint: string;
  readonly providerActionEnabled: false;
  readonly canonicalStateOperationEnabled: false;
}

export interface AppServerSupervisorFailure extends ProviderFailure {
  readonly lifecycle: readonly LifecyclePhase[];
  readonly handshakeOutcome: "failed";
  readonly shutdownOutcome: ShutdownOutcome;
  readonly stderrFingerprint: string;
}

export type AppServerSupervisorResult =
  | AppServerSupervisorSuccess
  | AppServerSupervisorFailure;

interface OwnedShutdownResult {
  readonly outcome: ShutdownOutcome;
  readonly failureCode?: "shutdown_timeout" | "shutdown_failed";
}

export async function superviseCodexAppServer(
  options: AppServerSupervisorOptions,
): Promise<AppServerSupervisorResult> {
  const lifecycle = new LifecycleTracker();
  lifecycle.transition("discovered");
  lifecycle.transition("starting");
  const stderrHash = createHash("sha256");
  let stderrBytes = 0;
  let child: ChildProcessWithoutNullStreams | undefined;
  let connection: JsonlRpcConnection | undefined;
  let failureCode: ProviderFailureCode | undefined;
  let onStderrData: ((chunk: Buffer) => void) | undefined;

  try {
    child = spawnOwned(options);
    onStderrData = (chunk: Buffer): void => {
      const remaining = STDERR_HASH_LIMIT - stderrBytes;
      if (remaining <= 0) return;
      const bounded = chunk.subarray(0, remaining);
      stderrHash.update(bounded);
      stderrBytes += bounded.length;
    };
    child.stderr.on("data", onStderrData);
    await waitForSpawn(child);
    lifecycle.transition("initializing");
    connection = new JsonlRpcConnection(child);
    await connection.initialize(options.initializationTimeoutMs);
    try {
      options.postInitializeCheck?.();
    } catch {
      throw new SupervisorAssertionError();
    }
    lifecycle.transition("initialized");
  } catch (error: unknown) {
    failureCode = classifyFailure(error, child);
    lifecycle.fail();
  }

  if (failureCode === undefined) lifecycle.transition("stopping");
  const shutdown = await stopOwnedChild(child, connection, options.shutdownTimeoutMs);
  let shutdownOutcome = shutdown.outcome;
  if (failureCode === "unexpected_exit_or_eof" && shutdownOutcome === "clean_exit") {
    shutdownOutcome = "unexpected_exit";
  }
  if (shutdown.failureCode) {
    failureCode = shutdown.failureCode;
    lifecycle.fail();
  } else if (failureCode === undefined) {
    lifecycle.transition("stopped");
  }
  const stderrFingerprint = await finalizeStderrFingerprint(
    child,
    stderrHash,
    onStderrData,
    options.shutdownTimeoutMs,
  );

  if (failureCode !== undefined) {
    const failure = createProviderFailure({
      code: failureCode,
      correlationId: options.correlationId,
      remediation: {
        action:
          failureCode === "spawn_failed" ? "repair_runtime" : "inspect_local_evidence",
        reference: failureCode,
      },
    });
    return Object.freeze({
      ...failure,
      lifecycle: lifecycle.history,
      handshakeOutcome: "failed",
      shutdownOutcome,
      stderrFingerprint,
    });
  }

  return Object.freeze({
    ok: true,
    correlationId: options.correlationId,
    lifecycle: lifecycle.history,
    handshakeOutcome: "initialized",
    shutdownOutcome,
    childPid: child?.pid ?? -1,
    stderrFingerprint,
    providerActionEnabled: false,
    canonicalStateOperationEnabled: false,
  });
}

function spawnOwned(options: AppServerSupervisorOptions): ChildProcessWithoutNullStreams {
  const spawnOptions: SpawnOptionsWithoutStdio = {
    cwd: options.workingDirectory,
    env: { ...options.environment },
    detached: process.platform !== "win32",
    shell: false,
  };
  return spawn(
    options.executablePath,
    ["app-server", "--stdio", "--strict-config"],
    { ...spawnOptions, stdio: ["pipe", "pipe", "pipe"] },
  );
}

async function waitForSpawn(child: ChildProcessWithoutNullStreams): Promise<void> {
  if (child.pid !== undefined) return;
  await new Promise<void>((resolveSpawn, rejectSpawn) => {
    child.once("spawn", resolveSpawn);
    child.once("error", rejectSpawn);
  });
}

async function stopOwnedChild(
  child: ChildProcessWithoutNullStreams | undefined,
  connection: JsonlRpcConnection | undefined,
  timeoutMs: number,
): Promise<OwnedShutdownResult> {
  if (!child?.pid) return { outcome: "not_started" };
  connection?.closeInput();
  if (await waitForOwnedExit(child, timeoutMs)) return { outcome: "clean_exit" };
  if (!signalOwned(child, "SIGTERM")) {
    return isOwnedProcessGroupAlive(child)
      ? { outcome: "shutdown_failure", failureCode: "shutdown_failed" }
      : { outcome: "clean_exit" };
  }
  if (await waitForOwnedExit(child, timeoutMs)) return { outcome: "graceful_termination" };
  if (!signalOwned(child, "SIGKILL")) {
    return isOwnedProcessGroupAlive(child)
      ? { outcome: "shutdown_failure", failureCode: "shutdown_failed" }
      : { outcome: "graceful_termination" };
  }
  if (await waitForOwnedExit(child, timeoutMs)) return { outcome: "forced_termination" };
  return { outcome: "shutdown_failure", failureCode: "shutdown_timeout" };
}

function signalOwned(child: ChildProcessWithoutNullStreams, signal: NodeJS.Signals): boolean {
  if (!child.pid) return false;
  try {
    if (process.platform === "win32") return child.kill(signal);
    process.kill(-child.pid, signal);
    return true;
  } catch {
    return false;
  }
}

function isOwnedProcessGroupAlive(child: ChildProcessWithoutNullStreams): boolean {
  if (!child.pid) return false;
  if (process.platform === "win32") return child.exitCode === null && child.signalCode === null;
  try {
    process.kill(-child.pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function waitForOwnedExit(
  child: ChildProcessWithoutNullStreams,
  timeoutMs: number,
): Promise<boolean> {
  if (!isOwnedProcessGroupAlive(child)) return true;
  return new Promise((resolveWait) => {
    let settled = false;
    const finish = (exited: boolean): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearInterval(poll);
      resolveWait(exited);
    };
    const poll = setInterval(() => {
      if (!isOwnedProcessGroupAlive(child)) finish(true);
    }, 10);
    poll.unref();
    const timer = setTimeout(() => finish(false), timeoutMs);
    timer.unref();
    if (!isOwnedProcessGroupAlive(child)) finish(true);
  });
}

async function finalizeStderrFingerprint(
  child: ChildProcessWithoutNullStreams | undefined,
  hash: ReturnType<typeof createHash>,
  onData: ((chunk: Buffer) => void) | undefined,
  timeoutMs: number,
): Promise<string> {
  if (child && onData) {
    await waitForStderrClose(child.stderr, timeoutMs);
    child.stderr.off("data", onData);
  }
  return hash.digest("hex");
}

async function waitForStderrClose(
  stream: ChildProcessWithoutNullStreams["stderr"],
  timeoutMs: number,
): Promise<void> {
  if (stream.closed || stream.destroyed || stream.readableEnded) return;
  await new Promise<void>((resolveClose) => {
    let settled = false;
    const finish = (): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      stream.off("close", finish);
      resolveClose();
    };
    stream.once("close", finish);
    const timer = setTimeout(finish, timeoutMs);
    timer.unref();
    if (stream.closed || stream.destroyed || stream.readableEnded) finish();
  });
}

function classifyFailure(
  error: unknown,
  child: ChildProcessWithoutNullStreams | undefined,
): ProviderFailureCode {
  if (error instanceof SupervisorAssertionError) return "isolation_failed";
  if (error instanceof HandshakeProtocolError) return error.code;
  if (child === undefined || child.pid === undefined) return "spawn_failed";
  return "unexpected_exit_or_eof";
}

class SupervisorAssertionError extends Error {
  constructor() {
    super("isolation_failed");
    this.name = "SupervisorAssertionError";
  }
}
