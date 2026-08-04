import { spawn, type ChildProcess } from "node:child_process";
import { readFile } from "node:fs/promises";

import {
  requireOwnedExecutableSnapshot,
  type ExecutableSnapshot,
} from "./executable-snapshot.ts";
import {
  compareSupportedProtocol,
  extractGeneratedProtocolMethods,
  createProtocolBoundary,
  isSafeRuntimeBuild,
  parseSupportedRuntimeManifest,
  sha256,
  type ProtocolBoundary,
  type SupportedRuntimeManifest,
} from "./protocol-contract.ts";
import {
  generateProtocolSchemas,
  ProtocolSchemaGenerationError,
  type GeneratedProtocolSchemas,
} from "./protocol-schema-generator.ts";

const MAX_MANIFEST_BYTES = 16 * 1024 * 1024;
const MAX_VERSION_BYTES = 4_096;
const compatibilityCapabilityBrand: unique symbol = Symbol("projectos.compatibility-capability");

export type CompatibilityCapability = Readonly<{
  readonly [compatibilityCapabilityBrand]: true;
}>;

interface CompatibilityCapabilityFacts {
  readonly attemptId: string;
  readonly executablePath: string;
  readonly binaryContentSha256: string;
  readonly manifestDigest: string;
  readonly protocolBoundary: ProtocolBoundary;
  consumed: boolean;
}

const compatibilityCapabilityFacts = new WeakMap<object, CompatibilityCapabilityFacts>();

export interface CompatibleAppServerSpawnAuthorization {
  readonly executablePath: string;
  readonly binaryContentSha256: string;
  readonly manifestDigest: string;
  readonly protocolBoundary: ProtocolBoundary;
}

export type SnapshotCompatibilityFailureReason =
  | "invalid_manifest"
  | "unsupported_build"
  | "unsupported_platform"
  | "unsupported_architecture"
  | "binary_mismatch"
  | "schema_generation_failed"
  | "schema_mismatch"
  | "missing_required_method"
  | "unsupported_dispatch"
  | "runtime_terminated";

export interface ValidateSnapshotCompatibilityOptions {
  readonly attemptId: string;
  readonly snapshot: ExecutableSnapshot;
  readonly manifestPath: string;
  readonly environment: Readonly<Record<string, string>>;
  readonly workingDirectory: string;
  readonly stagingDirectory: string;
  readonly versionTimeoutMs: number;
  readonly generatorTimeoutMs: number;
  readonly generatorShutdownStepMs: number;
}

export interface SnapshotCompatibilitySuccess {
  readonly ok: true;
  readonly capability: CompatibilityCapability;
  readonly detectedBuild: string;
  readonly manifest: SupportedRuntimeManifest;
  readonly manifestDigest: string;
  readonly generated: GeneratedProtocolSchemas;
  readonly detectedMethods: Awaited<ReturnType<typeof extractGeneratedProtocolMethods>>;
  readonly protocolBoundary: ProtocolBoundary;
  readonly ownedProcessesReaped: true;
}

export interface SnapshotCompatibilityFailure {
  readonly ok: false;
  readonly reason: SnapshotCompatibilityFailureReason;
  readonly detectedBuild?: string;
  readonly supportedBuild?: string;
  readonly manifest?: SupportedRuntimeManifest;
  readonly manifestDigest?: string;
  readonly generated?: GeneratedProtocolSchemas;
  readonly detectedMethods?: Awaited<ReturnType<typeof extractGeneratedProtocolMethods>>;
  readonly generationAttempted?: true;
  readonly ownedProcessesReaped: boolean;
}

export type SnapshotCompatibilityResult =
  | SnapshotCompatibilitySuccess
  | SnapshotCompatibilityFailure;

export async function validateSnapshotCompatibility(
  options: ValidateSnapshotCompatibilityOptions,
): Promise<SnapshotCompatibilityResult> {
  const ownedSnapshot = requireOwnedExecutableSnapshot(options.snapshot);
  let serializedManifest: string;
  let manifest: SupportedRuntimeManifest;
  try {
    const bytes = await readFile(options.manifestPath);
    if (bytes.length === 0 || bytes.length > MAX_MANIFEST_BYTES) return failure("invalid_manifest");
    serializedManifest = bytes.toString("utf8");
    manifest = parseSupportedRuntimeManifest(serializedManifest);
  } catch {
    return failure("invalid_manifest");
  }
  const manifestDigest = sha256(serializedManifest);

  let detectedBuild: string;
  try {
    detectedBuild = await probeSnapshotVersion(options);
  } catch (error: unknown) {
    return failure(
      "runtime_terminated",
      undefined,
      manifest.runtime.build,
      manifest,
      manifestDigest,
      undefined,
      undefined,
      undefined,
      !(error instanceof VersionProbeError) || error.ownedProcessGroupReaped,
    );
  }
  if (detectedBuild !== manifest.runtime.build) {
    return failure("unsupported_build", detectedBuild, manifest.runtime.build, manifest, manifestDigest);
  }
  if (process.platform !== manifest.runtime.platform) {
    return failure("unsupported_platform", detectedBuild, manifest.runtime.build, manifest, manifestDigest);
  }
  if (process.arch !== manifest.runtime.architecture) {
    return failure("unsupported_architecture", detectedBuild, manifest.runtime.build, manifest, manifestDigest);
  }
  if (ownedSnapshot.binaryContentSha256 !== manifest.runtime.binaryContentSha256) {
    return failure("binary_mismatch", detectedBuild, manifest.runtime.build, manifest, manifestDigest);
  }

  let generated: GeneratedProtocolSchemas;
  try {
    generated = await generateProtocolSchemas({
      executablePath: ownedSnapshot.executablePath,
      stagingDirectory: options.stagingDirectory,
      environment: options.environment,
      timeoutMs: options.generatorTimeoutMs,
      shutdownStepMs: options.generatorShutdownStepMs,
    });
  } catch (error: unknown) {
    return failure(
      error instanceof ProtocolSchemaGenerationError && error.reason === "terminated"
        ? "runtime_terminated"
        : "schema_generation_failed",
      detectedBuild,
      manifest.runtime.build,
      manifest,
      manifestDigest,
      undefined,
      undefined,
      true,
      !(error instanceof ProtocolSchemaGenerationError) || error.ownedProcessGroupReaped,
    );
  }

  let detectedMethods: Awaited<ReturnType<typeof extractGeneratedProtocolMethods>>;
  try {
    detectedMethods = await extractGeneratedProtocolMethods(generated.jsonDirectory);
  } catch {
    return failure(
      "schema_generation_failed",
      detectedBuild,
      manifest.runtime.build,
      manifest,
      manifestDigest,
      generated,
      undefined,
      true,
    );
  }
  const comparison = Object.freeze({
    manifest,
    detectedBuild,
    detectedPlatform: process.platform,
    detectedArchitecture: process.arch,
    binaryContentSha256: ownedSnapshot.binaryContentSha256,
    jsonBundle: generated.jsonBundle,
    typescriptBundle: generated.typescriptBundle,
    detectedMethods,
  });
  const validation = compareSupportedProtocol(comparison);
  if (!validation.ok) {
    return failure(
      validation.mismatch,
      detectedBuild,
      manifest.runtime.build,
      manifest,
      manifestDigest,
      generated,
      detectedMethods,
      true,
    );
  }
  const protocolBoundary = createProtocolBoundary(manifest, detectedMethods);
  return Object.freeze({
    ok: true,
    capability: mintCompatibilityCapability({
      attemptId: options.attemptId,
      executablePath: ownedSnapshot.executablePath,
      binaryContentSha256: ownedSnapshot.binaryContentSha256,
      manifestDigest,
      protocolBoundary,
      consumed: false,
    }),
    detectedBuild,
    manifest,
    manifestDigest,
    generated,
    detectedMethods,
    protocolBoundary,
    ownedProcessesReaped: true,
  });
}

export function authorizeCompatibleAppServerSpawn(
  capability: unknown,
  attemptId: string,
): CompatibleAppServerSpawnAuthorization {
  if (typeof capability !== "object" || capability === null) throw compatibilityRequired();
  const facts = compatibilityCapabilityFacts.get(capability);
  if (!facts || facts.attemptId !== attemptId || facts.consumed) throw compatibilityRequired();
  facts.consumed = true;
  return Object.freeze({
    executablePath: facts.executablePath,
    binaryContentSha256: facts.binaryContentSha256,
    manifestDigest: facts.manifestDigest,
    protocolBoundary: facts.protocolBoundary,
  });
}

function failure(
  reason: SnapshotCompatibilityFailureReason,
  detectedBuild?: string,
  supportedBuild?: string,
  manifest?: SupportedRuntimeManifest,
  manifestDigest?: string,
  generated?: GeneratedProtocolSchemas,
  detectedMethods?: Awaited<ReturnType<typeof extractGeneratedProtocolMethods>>,
  generationAttempted?: true,
  ownedProcessesReaped = true,
): SnapshotCompatibilityFailure {
  return Object.freeze({
    ok: false,
    reason,
    ...(detectedBuild ? { detectedBuild } : {}),
    ...(supportedBuild ? { supportedBuild } : {}),
    ...(manifest ? { manifest } : {}),
    ...(manifestDigest ? { manifestDigest } : {}),
    ...(generated ? { generated } : {}),
    ...(detectedMethods ? { detectedMethods } : {}),
    ...(generationAttempted ? { generationAttempted } : {}),
    ownedProcessesReaped,
  });
}

async function probeSnapshotVersion(options: ValidateSnapshotCompatibilityOptions): Promise<string> {
  const snapshot = requireOwnedExecutableSnapshot(options.snapshot);
  const child = spawn(snapshot.executablePath, ["--version"], {
    cwd: options.workingDirectory,
    env: { ...options.environment },
    detached: process.platform !== "win32",
    shell: false,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stdout = Buffer.alloc(0);
  let outputBytes = 0;
  child.stdout?.on("data", (chunk: Buffer) => {
    outputBytes += chunk.length;
    if (stdout.length < MAX_VERSION_BYTES) {
      stdout = Buffer.concat([stdout, chunk.subarray(0, MAX_VERSION_BYTES - stdout.length)]);
    }
  });
  child.stderr?.on("data", (chunk: Buffer) => {
    outputBytes += chunk.length;
  });
  const outcome = await waitForProbe(child, options.versionTimeoutMs);
  const reaped = await stopOwnedProbeGroup(child, options.generatorShutdownStepMs);
  const version = stdout.toString("utf8").trim();
  if (
    outcome !== "success" ||
    !reaped ||
    outputBytes > MAX_VERSION_BYTES ||
    !isSafeRuntimeBuild(version)
  ) {
    throw new VersionProbeError(reaped);
  }
  return version;
}

async function stopOwnedProbeGroup(child: ChildProcess, timeoutMs: number): Promise<boolean> {
  if (!isOwnedProbeGroupAlive(child)) return true;
  signalOwned(child, "SIGTERM");
  if (await waitForOwnedProbeGroupExit(child, timeoutMs)) return true;
  signalOwned(child, "SIGKILL");
  return waitForOwnedProbeGroupExit(child, timeoutMs);
}

async function waitForOwnedProbeGroupExit(
  child: ChildProcess,
  timeoutMs: number,
): Promise<boolean> {
  if (!isOwnedProbeGroupAlive(child)) return true;
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
      if (!isOwnedProbeGroupAlive(child)) finish(true);
    }, 10);
    poll.unref();
    const timer = setTimeout(() => finish(false), timeoutMs);
    timer.unref();
    if (!isOwnedProbeGroupAlive(child)) finish(true);
  });
}

async function waitForProbe(
  child: ChildProcess,
  timeoutMs: number,
): Promise<"success" | "failure" | "timeout"> {
  if (child.exitCode !== null || child.signalCode !== null) {
    return child.exitCode === 0 && child.signalCode === null ? "success" : "failure";
  }
  return new Promise((resolveProbe) => {
    let settled = false;
    const finish = (outcome: "success" | "failure" | "timeout"): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      child.off("exit", onExit);
      child.off("error", onError);
      resolveProbe(outcome);
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

function isOwnedProbeGroupAlive(child: ChildProcess): boolean {
  if (!child.pid) return false;
  if (process.platform === "win32") {
    return child.exitCode === null && child.signalCode === null;
  }
  try {
    process.kill(-child.pid, 0);
    return true;
  } catch {
    return false;
  }
}

function mintCompatibilityCapability(
  facts: CompatibilityCapabilityFacts,
): CompatibilityCapability {
  if (
    !/^[a-zA-Z0-9][a-zA-Z0-9._:-]{0,255}$/u.test(facts.attemptId) ||
    !/^[a-f0-9]{64}$/u.test(facts.binaryContentSha256) ||
    !/^[a-f0-9]{64}$/u.test(facts.manifestDigest)
  ) {
    throw compatibilityRequired();
  }
  const capability = Object.freeze({
    [compatibilityCapabilityBrand]: true,
  }) as CompatibilityCapability;
  compatibilityCapabilityFacts.set(capability, facts);
  return capability;
}

function compatibilityRequired(): Error {
  return new Error("protocol_compatibility_required");
}

class VersionProbeError extends Error {
  readonly ownedProcessGroupReaped: boolean;

  constructor(ownedProcessGroupReaped: boolean) {
    super("runtime_terminated");
    this.name = "VersionProbeError";
    this.ownedProcessGroupReaped = ownedProcessGroupReaped;
  }
}
