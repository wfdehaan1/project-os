import { constants } from "node:fs";
import { access, realpath, stat } from "node:fs/promises";
import { delimiter, isAbsolute, resolve } from "node:path";
import { spawn } from "node:child_process";

import { createProviderFailure, type ProviderFailure } from "../../core/failures.ts";

export interface ExecutableDiscoverySuccess {
  readonly ok: true;
  readonly candidatePath: string;
  readonly executablePath: string;
  readonly version: string;
}

export type ExecutableDiscoveryResult = ExecutableDiscoverySuccess | ProviderFailure;

export interface ExecutableDiscoveryOptions {
  readonly path?: string;
  readonly executableName?: string;
  readonly versionTimeoutMs?: number;
  readonly probeVersion?: (executablePath: string, timeoutMs: number) => Promise<string>;
}

const PRIVATE_APP_BUNDLE = /\.app[\\/]Contents[\\/]/u;
const VERSION_PATTERN = /^codex(?:-cli)?\s+\S+$/iu;
const MAX_VERSION_OUTPUT_BYTES = 4_096;

export async function discoverCodexExecutable(
  options: ExecutableDiscoveryOptions = {},
): Promise<ExecutableDiscoveryResult> {
  const executableName = options.executableName ?? "codex";
  if (!isExecutableBasename(executableName)) {
    return createProviderFailure({
      code: "runtime_not_found",
      remediation: { action: "install_runtime", reference: "codex" },
    });
  }
  const searchPath = options.path ?? process.env.PATH ?? "";
  let sawNonExecutable = false;

  for (const directory of searchPath.split(delimiter).filter(Boolean)) {
    const candidate = resolve(directory, executableName);
    if (PRIVATE_APP_BUNDLE.test(candidate)) continue;

    let resolvedPath: string;
    try {
      resolvedPath = await realpath(candidate);
      if (!isAbsolute(resolvedPath) || PRIVATE_APP_BUNDLE.test(resolvedPath)) continue;
      const candidateStat = await stat(resolvedPath);
      if (!candidateStat.isFile()) {
        sawNonExecutable = true;
        continue;
      }
      await access(resolvedPath, constants.X_OK);
    } catch (error: unknown) {
      if (isPermissionError(error)) sawNonExecutable = true;
      continue;
    }

    try {
      const version = await (options.probeVersion ?? probeCodexVersion)(
        resolvedPath,
        options.versionTimeoutMs ?? 2_000,
      );
      if (!VERSION_PATTERN.test(version)) throw new Error("invalid version shape");
      return { ok: true, candidatePath: candidate, executablePath: resolvedPath, version };
    } catch {
      return createProviderFailure({
        code: "version_probe_failed",
        remediation: { action: "repair_runtime", reference: executableName },
      });
    }
  }

  return createProviderFailure({
    code: sawNonExecutable ? "runtime_not_executable" : "runtime_not_found",
    remediation: {
      action: sawNonExecutable ? "repair_runtime" : "install_runtime",
      reference: executableName,
    },
  });
}

export async function probeCodexVersion(
  executablePath: string,
  timeoutMs: number,
): Promise<string> {
  return new Promise((resolveProbe, rejectProbe) => {
    const child = spawn(executablePath, ["--version"], {
      shell: false,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = Buffer.alloc(0);
    let stderrBytes = 0;
    let settled = false;
    let timer: NodeJS.Timeout;

    const settle = (error?: Error, value?: string): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      child.stdout.destroy();
      child.stderr.destroy();
      if (error) rejectProbe(error);
      else resolveProbe(value ?? "");
    };

    child.stdout.on("data", (chunk: Buffer) => {
      if (stdout.length >= MAX_VERSION_OUTPUT_BYTES) return;
      stdout = Buffer.concat([stdout, chunk.subarray(0, MAX_VERSION_OUTPUT_BYTES - stdout.length)]);
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderrBytes = Math.min(MAX_VERSION_OUTPUT_BYTES, stderrBytes + chunk.length);
    });
    child.once("error", (error) => settle(error));
    child.once("exit", (code, signal) => {
      if (code !== 0 || signal !== null || stderrBytes >= MAX_VERSION_OUTPUT_BYTES) {
        settle(new Error("version probe failed"));
        return;
      }
      settle(undefined, stdout.toString("utf8").trim());
    });

    timer = setTimeout(() => {
      child.kill("SIGKILL");
      settle(new Error("version probe timeout"));
    }, timeoutMs);
    timer.unref();
  });
}

function isPermissionError(error: unknown): boolean {
  return (
    error instanceof Error &&
    "code" in error &&
    (error.code === "EACCES" || error.code === "EPERM")
  );
}

function isExecutableBasename(value: string): boolean {
  return value.length > 0 && value !== "." && value !== ".." && !/[\\/]/u.test(value);
}
