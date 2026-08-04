import { spawn, type ChildProcess } from "node:child_process";
import { chmod, mkdir } from "node:fs/promises";
import { join } from "node:path";

import {
  collectProtocolSchemaBundle,
  type CollectProtocolSchemaBundleOptions,
  type ProtocolSchemaBundle,
} from "./protocol-contract.ts";

export const DEFAULT_SCHEMA_GENERATOR_TIMEOUT_MS = 5_000;
export const DEFAULT_SCHEMA_GENERATOR_SHUTDOWN_STEP_MS = 500;
const MAX_GENERATOR_OUTPUT_BYTES = 64 * 1024;

export interface GenerateProtocolSchemasOptions extends CollectProtocolSchemaBundleOptions {
  readonly executablePath: string;
  readonly stagingDirectory: string;
  readonly environment: Readonly<Record<string, string>>;
  readonly timeoutMs?: number;
  readonly shutdownStepMs?: number;
}

export interface GeneratedProtocolSchemas {
  readonly jsonDirectory: string;
  readonly typescriptDirectory: string;
  readonly jsonBundle: ProtocolSchemaBundle;
  readonly typescriptBundle: ProtocolSchemaBundle;
}

export class ProtocolSchemaGenerationError extends Error {
  readonly reason: "timeout" | "terminated" | "failed" | "invalid_output";
  readonly ownedProcessGroupReaped: boolean;

  constructor(
    reason: "timeout" | "terminated" | "failed" | "invalid_output",
    ownedProcessGroupReaped = true,
  ) {
    super("schema_generation_failed");
    this.name = "ProtocolSchemaGenerationError";
    this.reason = reason;
    this.ownedProcessGroupReaped = ownedProcessGroupReaped;
  }
}

export async function generateProtocolSchemas(
  options: GenerateProtocolSchemasOptions,
): Promise<GeneratedProtocolSchemas> {
  await mkdir(options.stagingDirectory, { recursive: false, mode: 0o700 });
  await chmod(options.stagingDirectory, 0o700);
  const jsonDirectory = join(options.stagingDirectory, "json");
  const typescriptDirectory = join(options.stagingDirectory, "typescript");
  await runGenerator(options, ["app-server", "generate-json-schema", "--out", jsonDirectory]);
  await runGenerator(options, ["app-server", "generate-ts", "--out", typescriptDirectory]);
  try {
    const limits = {
      ...(options.maximumFiles === undefined ? {} : { maximumFiles: options.maximumFiles }),
      ...(options.maximumFileBytes === undefined ? {} : { maximumFileBytes: options.maximumFileBytes }),
      ...(options.maximumBundleBytes === undefined ? {} : { maximumBundleBytes: options.maximumBundleBytes }),
    };
    return Object.freeze({
      jsonDirectory,
      typescriptDirectory,
      jsonBundle: await collectProtocolSchemaBundle(jsonDirectory, "json", limits),
      typescriptBundle: await collectProtocolSchemaBundle(typescriptDirectory, "typescript", limits),
    });
  } catch {
    throw new ProtocolSchemaGenerationError("invalid_output");
  }
}

async function runGenerator(
  options: GenerateProtocolSchemasOptions,
  arguments_: readonly string[],
): Promise<void> {
  const timeoutMs = options.timeoutMs ?? DEFAULT_SCHEMA_GENERATOR_TIMEOUT_MS;
  const shutdownStepMs = options.shutdownStepMs ?? DEFAULT_SCHEMA_GENERATOR_SHUTDOWN_STEP_MS;
  const child = spawn(options.executablePath, [...arguments_], {
    cwd: options.stagingDirectory,
    env: { ...options.environment },
    detached: process.platform !== "win32",
    shell: false,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let outputBytes = 0;
  let outputExceeded = false;
  const countOutput = (chunk: Buffer): void => {
    outputBytes += chunk.length;
    if (outputBytes > MAX_GENERATOR_OUTPUT_BYTES) {
      outputExceeded = true;
      signalOwned(child, "SIGKILL");
    }
  };
  child.stdout?.on("data", countOutput);
  child.stderr?.on("data", countOutput);

  const outcome = await waitForExit(child, timeoutMs);
  if (outcome === "timeout") {
    const reaped = await stopOwnedGroup(child, shutdownStepMs);
    throw new ProtocolSchemaGenerationError("timeout", reaped);
  }
  if (outcome !== "success" || outputExceeded) {
    const reaped = await stopOwnedGroup(child, shutdownStepMs);
    throw new ProtocolSchemaGenerationError(
      !outputExceeded && child.signalCode !== null ? "terminated" : "failed",
      reaped,
    );
  }
  if (!(await stopOwnedGroup(child, shutdownStepMs))) {
    throw new ProtocolSchemaGenerationError("failed", false);
  }
}

async function stopOwnedGroup(child: ChildProcess, timeoutMs: number): Promise<boolean> {
  if (!isOwnedAlive(child)) return true;
  signalOwned(child, "SIGTERM");
  if (await waitForOwnedGroupExit(child, timeoutMs)) return true;
  signalOwned(child, "SIGKILL");
  return waitForOwnedGroupExit(child, timeoutMs);
}

async function waitForOwnedGroupExit(child: ChildProcess, timeoutMs: number): Promise<boolean> {
  if (!isOwnedAlive(child)) return true;
  return new Promise((resolveWait) => {
    let settled = false;
    const finish = (stopped: boolean): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearInterval(poll);
      resolveWait(stopped);
    };
    const poll = setInterval(() => {
      if (!isOwnedAlive(child)) finish(true);
    }, 10);
    poll.unref();
    const timer = setTimeout(() => finish(false), timeoutMs);
    timer.unref();
    if (!isOwnedAlive(child)) finish(true);
  });
}

async function waitForExit(
  child: ChildProcess,
  timeoutMs: number,
): Promise<"success" | "failure" | "timeout"> {
  if (child.exitCode !== null || child.signalCode !== null) {
    return child.exitCode === 0 && child.signalCode === null ? "success" : "failure";
  }
  return new Promise((resolveExit) => {
    let settled = false;
    const finish = (outcome: "success" | "failure" | "timeout"): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      child.off("exit", onExit);
      child.off("error", onError);
      resolveExit(outcome);
    };
    const onExit = (code: number | null, signal: NodeJS.Signals | null): void =>
      finish(code === 0 && signal === null ? "success" : "failure");
    const onError = (): void => finish("failure");
    child.once("exit", onExit);
    child.once("error", onError);
    const timer = setTimeout(() => finish("timeout"), timeoutMs);
    timer.unref();
    if (child.exitCode !== null || child.signalCode !== null) onExit(child.exitCode, child.signalCode);
  });
}

function signalOwned(child: ChildProcess, signal: NodeJS.Signals): boolean {
  if (!child.pid) return false;
  try {
    if (process.platform === "win32") return child.kill(signal);
    process.kill(-child.pid, signal);
    return true;
  } catch {
    return false;
  }
}

function isOwnedAlive(child: ChildProcess): boolean {
  if (!child.pid) return false;
  try {
    if (process.platform === "win32") return child.exitCode === null && child.signalCode === null;
    process.kill(-child.pid, 0);
    return true;
  } catch {
    return false;
  }
}
