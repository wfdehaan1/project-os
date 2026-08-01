import { randomUUID } from "node:crypto";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, type ChildProcess } from "node:child_process";

import type {
  AiProviderPort,
  RuntimeHealthResult,
  RuntimeValidationRequest,
} from "../../core/ai-provider-port.ts";
import {
  createCorrelationId,
  createProviderFailure,
  type ProviderFailure,
} from "../../core/failures.ts";
import type { LifecyclePhase } from "../../core/lifecycle.ts";
import type { PrivateRunEvidence } from "../../evidence/evidence-schema.ts";
import { writeRunEvidence, type EvidencePaths } from "../../evidence/evidence-recorder.ts";
import {
  superviseCodexAppServer,
  type AppServerSupervisorResult,
} from "./app-server-supervisor.ts";
import {
  discoverCodexExecutable,
  type ExecutableDiscoveryResult,
} from "./executable-discovery.ts";
import {
  assertFixtureUnchanged,
  createIsolatedRuntimeProfile,
  createSyntheticNormalProfileFixture,
  snapshotFixture,
  type IsolatedRuntimeProfile,
} from "./runtime-profile.ts";

type EvidenceWriter = (
  evidence: PrivateRunEvidence,
  evidenceRoot: string,
) => Promise<EvidencePaths>;

export interface CodexAppServerAdapterDependencies {
  readonly discover?: typeof discoverCodexExecutable;
  readonly createProfile?: typeof createIsolatedRuntimeProfile;
  readonly supervise?: typeof superviseCodexAppServer;
  readonly writeEvidence?: EvidenceWriter;
  readonly evidenceRoot?: string;
  readonly now?: () => Date;
  readonly runId?: () => string;
  readonly correlationId?: () => string;
}

const DEFAULT_EVIDENCE_ROOT = fileURLToPath(new URL("../../../.evidence", import.meta.url));
const REPRODUCTION_COMMAND = "npm ci && npm run validate:full";

export class CodexAppServerAdapter implements AiProviderPort {
  readonly #discover: typeof discoverCodexExecutable;
  readonly #createProfile: typeof createIsolatedRuntimeProfile;
  readonly #supervise: typeof superviseCodexAppServer;
  readonly #writeEvidence: EvidenceWriter;
  readonly #evidenceRoot: string;
  readonly #now: () => Date;
  readonly #runId: () => string;
  readonly #correlationId: () => string;

  constructor(dependencies: CodexAppServerAdapterDependencies = {}) {
    this.#discover = dependencies.discover ?? discoverCodexExecutable;
    this.#createProfile = dependencies.createProfile ?? createIsolatedRuntimeProfile;
    this.#supervise = dependencies.supervise ?? superviseCodexAppServer;
    this.#writeEvidence = dependencies.writeEvidence ?? writeRunEvidence;
    this.#evidenceRoot = dependencies.evidenceRoot ?? DEFAULT_EVIDENCE_ROOT;
    this.#now = dependencies.now ?? (() => new Date());
    this.#runId = dependencies.runId ?? (() => `run-${randomUUID()}`);
    this.#correlationId = dependencies.correlationId ?? createCorrelationId;
  }

  async validateRuntime(request: RuntimeValidationRequest): Promise<RuntimeHealthResult> {
    const startedAt = this.#now().toISOString();
    const runId = this.#runId();
    const correlationId = this.#correlationId();
    let discovery: ExecutableDiscoveryResult | undefined;
    let profile: IsolatedRuntimeProfile | undefined;
    let supervisor: AppServerSupervisorResult | undefined;
    let failure: ProviderFailure | undefined;
    let isolationComparison: PrivateRunEvidence["isolationComparison"] = "not_completed";
    let sentinel: ChildProcess | undefined;

    try {
      discovery = await this.#discover({
        ...(request.path ? { path: request.path } : {}),
        ...(request.executableName ? { executableName: request.executableName } : {}),
      });
      if (!discovery.ok) {
        failure = withCorrelation(discovery, correlationId);
      } else {
        const fixtureRoot = await mkdtemp(join(tmpdir(), "projectos-harness-fixture-"));
        const normalProfile = await createSyntheticNormalProfileFixture(
          join(fixtureRoot, "normal-profile"),
        );
        const before = await snapshotFixture(normalProfile);
        sentinel = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
          detached: process.platform !== "win32",
          env: {},
          stdio: "ignore",
        });
        profile = await this.#createProfile({
          baseDirectory: join(fixtureRoot, "runs"),
          normalProfileRoot: normalProfile,
          ...(request.certificateConfiguration
            ? { certificateConfiguration: request.certificateConfiguration }
            : {}),
        });
        supervisor = await this.#supervise({
          executablePath: discovery.executablePath,
          workingDirectory: profile.workingDirectory,
          environment: profile.childEnvironment,
          initializationTimeoutMs: request.initializationTimeoutMs ?? 5_000,
          shutdownTimeoutMs: request.shutdownTimeoutMs ?? 500,
          correlationId,
        });
        try {
          await assertFixtureUnchanged(before, await snapshotFixture(normalProfile));
        } catch {
          isolationComparison = "changed";
          throw new Error("isolation_failed");
        }
        if (!isAlive(sentinel.pid)) throw new Error("isolation_failed");
        isolationComparison = "unchanged";
        if (!supervisor.ok) failure = supervisor;
      }
    } catch {
      failure = createProviderFailure({
        code: "isolation_failed",
        correlationId,
        remediation: { action: "check_permissions", reference: "isolated_runtime" },
      });
    }

    const lifecycle = supervisor?.lifecycle ?? defaultFailureLifecycle(discovery);
    const shutdownOutcome = supervisor?.shutdownOutcome ?? "not_started";
    const privateEvidence: PrivateRunEvidence = {
      schemaVersion: 1,
      runId,
      correlationId,
      startedAt,
      completedAt: this.#now().toISOString(),
      harnessVersion: "0.1.0",
      nodeVersion: process.version,
      runtimeVersion: discovery?.ok ? discovery.version : null,
      candidateExecutablePath: discovery?.ok ? discovery.candidatePath : null,
      resolvedExecutablePath: discovery?.ok ? discovery.executablePath : null,
      runtimePaths: profile
        ? {
            runtimeRoot: profile.runtimeRoot,
            codexHome: profile.codexHome,
            codexSqliteHome: profile.codexSqliteHome,
            disposableHome: profile.disposableHome,
            workingDirectory: profile.workingDirectory,
            temporaryDirectory: profile.temporaryDirectory,
            configPath: profile.configPath,
          }
        : null,
      strictConfigurationFingerprint: profile?.strictConfigurationFingerprint ?? null,
      allowedEnvironmentNames: profile?.allowedEnvironmentNames ?? [],
      environmentFingerprints: profile?.environmentFingerprints ?? {},
      lifecycle,
      handshakeOutcome: supervisor?.ok ? "initialized" : "failed",
      shutdownOutcome,
      isolationComparison,
      result: failure ? "failed" : "passed",
      failureCode: failure?.code,
      reproductionCommand: REPRODUCTION_COMMAND,
    };

    try {
      await this.#writeEvidence(privateEvidence, this.#evidenceRoot);
    } catch (error: unknown) {
      void error;
      failure = createProviderFailure({
        code: "evidence_write_failed",
        correlationId,
        remediation: { action: "check_permissions", reference: "evidence_directory" },
      });
    } finally {
      stopSentinel(sentinel);
    }

    if (failure) return failure;
    if (!discovery?.ok || !supervisor?.ok) {
      return createProviderFailure({
        code: "isolation_failed",
        correlationId,
        remediation: { action: "inspect_local_evidence" },
      });
    }
    return Object.freeze({
      ok: true,
      correlationId,
      lifecycle: supervisor.lifecycle,
      runtimeVersion: discovery.version,
      shutdownOutcome: supervisor.shutdownOutcome,
      providerActionEnabled: false,
      canonicalStateOperationEnabled: false,
    });
  }
}

function withCorrelation(failure: ProviderFailure, correlationId: string): ProviderFailure {
  return createProviderFailure({
    code: failure.code,
    correlationId,
    remediation: failure.remediation,
  });
}

function defaultFailureLifecycle(
  discovery: ExecutableDiscoveryResult | undefined,
): readonly LifecyclePhase[] {
  return discovery?.ok ? ["undiscovered", "discovered", "failed"] : ["undiscovered", "failed"];
}

function isAlive(pid: number | undefined): boolean {
  if (!pid) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function stopSentinel(sentinel: ChildProcess | undefined): void {
  if (!sentinel?.pid || !isAlive(sentinel.pid)) return;
  try {
    if (process.platform === "win32") sentinel.kill("SIGKILL");
    else process.kill(-sentinel.pid, "SIGKILL");
  } catch {
    // The exact sentinel may have already exited after the liveness comparison.
  }
}
