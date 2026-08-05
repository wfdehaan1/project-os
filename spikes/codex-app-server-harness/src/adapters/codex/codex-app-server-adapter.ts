import { spawn, type ChildProcess } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import type {
  AiProviderPort,
  AllowanceValidationRequest,
  AllowanceValidationResult,
  AuthenticationValidationRequest,
  AuthenticationValidationResult,
  RuntimeHealthResult,
  RuntimeValidationRequest,
  StructuredOutputValidationRequest,
  StructuredOutputValidationRejection,
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
  PROTOCOL_EVIDENCE_SCHEMA_VERSION,
  type PrivateProtocolAttemptEvidence,
  type ProtocolEvidenceAttachment,
  type ProtocolEvidencePackage,
} from "../../evidence/protocol-evidence-schema.ts";
import {
  superviseCodexAppServer,
  type AppServerSupervisorResult,
} from "./app-server-supervisor.ts";
import {
  discoverCodexExecutable,
  type ExecutableDiscoveryResult,
} from "./executable-discovery.ts";
import {
  createExecutableSnapshot,
  type ExecutableSnapshot,
} from "./executable-snapshot.ts";
import {
  validateSnapshotCompatibility,
  type SnapshotCompatibilityFailureReason,
  type SnapshotCompatibilityResult,
} from "./runtime-compatibility.ts";
import {
  assertFixtureUnchanged,
  auditProjectOSProfileCredentialOwnership,
  createIsolatedRuntimeProfile,
  createSyntheticNormalProfileFixture,
  snapshotFixture,
  type FixtureSnapshot,
  type IsolatedRuntimeProfile,
} from "./runtime-profile.ts";
import type { AuthenticationExchangeResult } from "./jsonl-rpc-connection.ts";
import type { AllowanceExchangeResult } from "./jsonl-rpc-connection.ts";
import { normalizeAllowanceBuckets } from "../../core/allowance.ts";
import { writeAuthenticationEvidence } from "../../evidence/authentication-evidence-recorder.ts";

type EvidenceWriter = (
  evidence: PrivateRunEvidence,
  evidenceRoot: string,
  protocol?: ProtocolEvidencePackage,
) => Promise<EvidencePaths>;

export interface CodexAppServerAdapterDependencies {
  readonly discover?: typeof discoverCodexExecutable;
  readonly createProfile?: typeof createIsolatedRuntimeProfile;
  readonly writeEvidence?: EvidenceWriter;
  readonly evidenceRoot?: string;
  readonly manifestPath?: string;
  readonly now?: () => Date;
  readonly runId?: () => string;
  readonly correlationId?: () => string;
  /** Receives the managed browser URL transiently; callers must not retain it. */
  readonly openLoginUrl?: (url: string) => Promise<void> | void;
}

interface AttemptState {
  readonly attemptId: string;
  readonly correlationId: string;
  readonly discovery: ExecutableDiscoveryResult | undefined;
  readonly profile: IsolatedRuntimeProfile | undefined;
  readonly snapshot: ExecutableSnapshot | undefined;
  readonly compatibility: SnapshotCompatibilityResult | undefined;
  readonly supervisor: AppServerSupervisorResult | undefined;
  readonly failure: ProviderFailure | undefined;
  readonly underlyingFailure: ProviderFailure | undefined;
  readonly isolationComparison: PrivateRunEvidence["isolationComparison"];
}

interface AttemptContext {
  readonly request: RuntimeValidationRequest;
  readonly correlationId: string;
  readonly fixtureRoot: string;
  readonly normalProfile: string;
  readonly normalProfileBefore: FixtureSnapshot;
  readonly sentinel: ChildProcess;
}

const DEFAULT_EVIDENCE_ROOT = fileURLToPath(new URL("../../../.evidence", import.meta.url));
const DEFAULT_MANIFEST_PATH = fileURLToPath(
  new URL("../../../protocol/supported-runtime-manifest.json", import.meta.url),
);
const REPRODUCTION_COMMAND = "npm ci && npm run validate:full";
const PROTOCOL_REPRODUCTION_COMMAND = "npm ci && npm run protocol:validate";
const PROTOCOL_RESTART_REPRODUCTION_COMMAND =
  "npm ci && npm run protocol:validate -- --restart";
const AUTH_REPRODUCTION_COMMAND = "PROJECTOS_LIVE_AUTH=1 npm run test:auth:live";
const ALLOWANCE_REPRODUCTION_COMMAND = "PROJECTOS_LIVE_ALLOWANCE=1 npm run test:allowance:live";
const STRUCTURED_OUTPUT_REPRODUCTION_COMMAND = "npm run validate:structured-output";

export class CodexAppServerAdapter implements AiProviderPort {
  readonly #discover: typeof discoverCodexExecutable;
  readonly #createProfile: typeof createIsolatedRuntimeProfile;
  readonly #writeEvidence: EvidenceWriter;
  readonly #evidenceRoot: string;
  readonly #manifestPath: string;
  readonly #now: () => Date;
  readonly #runId: () => string;
  readonly #correlationId: () => string;
  readonly #openLoginUrl: ((url: string) => Promise<void> | void) | undefined;

  constructor(dependencies: CodexAppServerAdapterDependencies = {}) {
    this.#discover = dependencies.discover ?? discoverCodexExecutable;
    this.#createProfile = dependencies.createProfile ?? createIsolatedRuntimeProfile;
    this.#writeEvidence = dependencies.writeEvidence ?? writeRunEvidence;
    this.#evidenceRoot = dependencies.evidenceRoot ?? DEFAULT_EVIDENCE_ROOT;
    this.#manifestPath = dependencies.manifestPath ?? DEFAULT_MANIFEST_PATH;
    this.#now = dependencies.now ?? (() => new Date());
    this.#runId = dependencies.runId ?? (() => `run-${randomUUID()}`);
    this.#correlationId = dependencies.correlationId ?? createCorrelationId;
    this.#openLoginUrl = dependencies.openLoginUrl;
  }

  async validateRuntime(request: RuntimeValidationRequest): Promise<RuntimeHealthResult> {
    const startedAt = this.#now().toISOString();
    const runId = this.#runId();
    const correlationId = this.#correlationId();
    const attempts: AttemptState[] = [];
    let sentinel: ChildProcess | undefined;
    let finalAttempt: AttemptState;

    try {
      const fixtureRoot = await mkdtemp(join(tmpdir(), "projectos-harness-fixture-"));
      const normalProfile = await createSyntheticNormalProfileFixture(
        join(fixtureRoot, "normal-profile"),
      );
      const normalProfileBefore = await snapshotFixture(normalProfile);
      sentinel = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
        detached: process.platform !== "win32",
        env: {},
        stdio: "ignore",
      });
      const context: AttemptContext = {
        request,
        correlationId,
        fixtureRoot,
        normalProfile,
        normalProfileBefore,
        sentinel,
      };
      const first = await this.#runAttempt(context, 1);
      attempts.push(first);
      finalAttempt = first;

      if (request.restart === true && first.failure) {
        if (!restartIsSafe(first)) {
          finalAttempt = withRestartFailure(first);
          attempts[0] = finalAttempt;
        } else {
          const second = await this.#runAttempt(context, 2);
          attempts.push(second);
          finalAttempt = second.failure ? withRestartFailure(second) : second;
          attempts[1] = finalAttempt;
        }
      }
    } catch {
      const attemptId = `attempt-1-${randomUUID()}`;
      const attemptCorrelationId = attemptCorrelation(correlationId, attemptId);
      finalAttempt = failedAttempt(
        attemptId,
        attemptCorrelationId,
        createProviderFailure({
          code: "isolation_failed",
          correlationId: attemptCorrelationId,
          remediation: { action: "check_permissions", reference: "isolated_runtime" },
          diagnosticReference: diagnosticReference(attemptCorrelationId),
        }),
      );
      attempts.push(finalAttempt);
    }

    let failure = finalAttempt.failure;
    const discovery = finalAttempt.discovery;
    const profile = finalAttempt.profile;
    const compatibility = finalAttempt.compatibility;
    const supervisor = finalAttempt.supervisor;
    const lifecycle = supervisor?.lifecycle ?? defaultFailureLifecycle(discovery);
    const shutdownOutcome = supervisor?.shutdownOutcome ?? "not_started";
    const authoritativeVersion = compatibility?.detectedBuild ?? null;
    const privateEvidence: PrivateRunEvidence = {
      schemaVersion: 1,
      runId,
      correlationId,
      startedAt,
      completedAt: this.#now().toISOString(),
      harnessVersion: "0.1.0",
      nodeVersion: process.version,
      runtimeVersion: authoritativeVersion,
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
      isolationComparison: finalAttempt.isolationComparison,
      result: failure ? "failed" : "passed",
      failureCode: failure?.code,
      reproductionCommand: REPRODUCTION_COMMAND,
    };

    try {
      await this.#writeEvidence(
        privateEvidence,
        this.#evidenceRoot,
        createProtocolEvidencePackage(
          runId,
          correlationId,
          attempts,
          failure,
          request.restart === true,
        ),
      );
    } catch {
      failure = createProviderFailure({
        code: "evidence_write_failed",
        correlationId,
        remediation: { action: "check_permissions", reference: "evidence_directory" },
        diagnosticReference: diagnosticReference(correlationId),
      });
    } finally {
      stopSentinel(sentinel);
    }

    if (failure) return failure;
    if (!discovery?.ok || !supervisor?.ok || !compatibility?.ok) {
      return createProviderFailure({
        code: "isolation_failed",
        correlationId,
        remediation: { action: "inspect_local_evidence" },
        diagnosticReference: diagnosticReference(correlationId),
      });
    }
    return Object.freeze({
      ok: true,
      correlationId,
      lifecycle: supervisor.lifecycle,
      runtimeVersion: compatibility.detectedBuild,
      compatibilityStatus: "compatible",
      attemptId: finalAttempt.attemptId,
      attemptCount: attempts.length as 1 | 2,
      manifestId: compatibility.manifest.manifestId,
      schemaDigests: Object.freeze({
        jsonSha256: compatibility.generated.jsonBundle.aggregateSha256,
        typescriptSha256: compatibility.generated.typescriptBundle.aggregateSha256,
      }),
      shutdownOutcome: supervisor.shutdownOutcome,
      providerActionEnabled: false,
      canonicalStateOperationEnabled: false,
    });
  }

  async validateAuthentication(
    request: AuthenticationValidationRequest,
  ): Promise<AuthenticationValidationResult> {
    const correlationId = this.#correlationId();
    let sentinel: ChildProcess | undefined;
    try {
      const fixtureRoot = await mkdtemp(join(tmpdir(), "projectos-auth-fixture-"));
      const normalProfile = await createSyntheticNormalProfileFixture(join(fixtureRoot, "normal-profile"));
      const normalProfileBefore = await snapshotFixture(normalProfile);
      sentinel = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
        detached: process.platform !== "win32", env: {}, stdio: "ignore",
      });
      const context: AttemptContext = { request, correlationId, fixtureRoot, normalProfile, normalProfileBefore, sentinel };
      const authentication: { result?: AuthenticationExchangeResult } = {};
      const attempt = await this.#runAttempt(context, 1, {
        interactive: request.interactive === true,
        timeoutMs: request.authenticationTimeoutMs ?? 120_000,
        deviceCodeRecovery: request.deviceCodeRecovery === true,
        result: authentication,
      });
      if (attempt.failure) return this.#recordAuthenticationFailure(attempt.failure);
      if (!attempt.profile || !attempt.supervisor?.ok || !authentication.result) {
        return this.#recordAuthenticationFailure(createProviderFailure({
          code: "authentication_failed",
          correlationId,
          remediation: { action: "inspect_local_evidence", reference: "authentication" },
        }));
      }
      const credentialOwnership = await auditProjectOSProfileCredentialOwnership(attempt.profile);
      await assertFixtureUnchanged(normalProfileBefore, await snapshotFixture(normalProfile));
      if (!isAlive(sentinel.pid)) throw new Error("isolation_failed");
      const deviceCodeCapability = attempt.compatibility?.ok &&
        attempt.compatibility.deviceCodeRecoverySupported === true
        ? "supported"
        : "unsupported";
      const result = Object.freeze({
        ok: true,
        correlationId,
        authenticationState: authentication.result.state,
        planCategory: authentication.result.planCategory,
        expectedPro: authentication.result.expectedPro,
        deviceCodeCapability,
        logoutOutcome: authentication.result.logoutOutcome,
        profileIsolation: "unchanged",
        credentialOwnership,
        retryable: ["cancelled", "expired", "failed", "secure_storage_unavailable"].includes(authentication.result.state),
        shutdownOutcome: attempt.supervisor.shutdownOutcome,
        providerActionEnabled: false,
        canonicalStateOperationEnabled: false,
      });
      const rejection = authenticationRejection(authentication.result);
      if (rejection) {
        return this.#recordAuthenticationRejection(result, rejection);
      }
      try {
        await writeAuthenticationEvidence({
          schemaVersion: 1, runId: this.#runId(), correlationId,
          result: "proceed", authenticationState: result.authenticationState,
          planCategory: result.planCategory, expectedPro: result.expectedPro,
          deviceCodeCapability: result.deviceCodeCapability, logoutOutcome: result.logoutOutcome,
          profileIsolation: result.profileIsolation, credentialOwnership: result.credentialOwnership,
          retryable: false, failureCode: null, reproductionCommand: AUTH_REPRODUCTION_COMMAND,
        }, this.#evidenceRoot);
      } catch {
        return createProviderFailure({
          code: "evidence_write_failed",
          correlationId,
          remediation: { action: "check_permissions", reference: "evidence_directory" },
        });
      }
      return result;
    } catch {
      return this.#recordAuthenticationFailure(createProviderFailure({
        code: "credential_ownership_rejected", correlationId,
        remediation: { action: "check_permissions", reference: "credential_ownership" },
      }));
    } finally {
      stopSentinel(sentinel);
    }
  }

  async validateAllowance(request: AllowanceValidationRequest): Promise<AllowanceValidationResult> {
    const correlationId = this.#correlationId();
    let sentinel: ChildProcess | undefined;
    try {
      const fixtureRoot = await mkdtemp(join(tmpdir(), "projectos-allowance-fixture-"));
      const normalProfile = await createSyntheticNormalProfileFixture(join(fixtureRoot, "normal-profile"));
      const normalProfileBefore = await snapshotFixture(normalProfile);
      sentinel = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], { detached: process.platform !== "win32", env: {}, stdio: "ignore" });
      const context: AttemptContext = { request, correlationId, fixtureRoot, normalProfile, normalProfileBefore, sentinel };
      const allowance: { result?: AllowanceExchangeResult } = {};
      const timeoutMs = typeof request.allowanceTimeoutMs === "number" && Number.isSafeInteger(request.allowanceTimeoutMs) && request.allowanceTimeoutMs > 0
        ? request.allowanceTimeoutMs
        : 10_000;
      const attempt = await this.#runAttempt(context, 1, undefined, { timeoutMs, result: allowance });
      if (attempt.failure) return this.#recordAllowanceFailure(attempt.failure.code === "malformed_handshake_response"
        ? createProviderFailure({ code: "allowance_malformed", correlationId, remediation: { action: "inspect_local_evidence", reference: "allowance_shape" } })
        : attempt.failure);
      if (!attempt.compatibility?.ok || !attempt.supervisor?.ok || !allowance.result) {
        return this.#recordAllowanceFailure(createProviderFailure({ code: "allowance_malformed", correlationId, remediation: { action: "inspect_local_evidence", reference: "allowance" } }));
      }
      const normalized = normalizeAllowanceBuckets(allowance.result.buckets);
      const result = Object.freeze({ ok: true as const, correlationId, runtimeVersion: attempt.compatibility.detectedBuild,
        providerReadiness: normalized.providerReadiness, localProjectOSCapability: "available" as const,
        buckets: normalized.buckets, remedy: normalized.remedy, shutdownOutcome: attempt.supervisor.shutdownOutcome,
        providerActionEnabled: false as const, canonicalStateOperationEnabled: false as const });
      try { await this.#writeAllowanceEvidence(result, null); }
      catch {
        return createProviderFailure({ code: "evidence_write_failed", correlationId, remediation: { action: "check_permissions", reference: "evidence_directory" } });
      }
      return result;
    } catch {
      return this.#recordAllowanceFailure(createProviderFailure({ code: "allowance_malformed", correlationId, remediation: { action: "inspect_local_evidence", reference: "allowance" } }));
    } finally { stopSentinel(sentinel); }
  }

  /**
   * Story 1.5 deliberately has no path to a provider thread or turn. A containment
   * attestation can only be minted by the preventive gate in Story 1.6, so reject
   * before discovery, profile creation, schema generation, or child process spawn.
   */
  async validateStructuredOutput(
    _request: StructuredOutputValidationRequest,
  ): Promise<StructuredOutputValidationRejection> {
    const correlationId = this.#correlationId();
    let evidenceFailed = false;
    try {
      const { writeStructuredOutputEvidence } = await import("../../evidence/structured-output-evidence-recorder.ts");
      await writeStructuredOutputEvidence({
        schemaVersion: 1,
        runId: this.#runId(),
        correlationId,
        result: "reject",
        scorePercent: null,
        scores: [],
        stopConditions: ["containment_attestation_required"],
        containment: "unavailable",
        reproductionCommand: STRUCTURED_OUTPUT_REPRODUCTION_COMMAND,
      }, this.#evidenceRoot);
    } catch { evidenceFailed = true; }
    // This is still a no-dispatch denial. Do not widen to any provider action if evidence fails.
    return Object.freeze({ ok: false, code: evidenceFailed ? "evidence_write_failed" : "containment_attestation_required", correlationId,
      stopCondition: evidenceFailed ? "evidence_write_failed" : "containment_attestation_required", providerActionEnabled: false,
      canonicalStateOperationEnabled: false });
  }

  async #recordAllowanceFailure(failure: ProviderFailure): Promise<ProviderFailure> {
    if (failure.code === "evidence_write_failed") return failure;
    try { await this.#writeAllowanceEvidence(undefined, failure); return failure; }
    catch { return createProviderFailure({ code: "evidence_write_failed", correlationId: failure.correlationId, remediation: { action: "check_permissions", reference: "evidence_directory" } }); }
  }

  async #writeAllowanceEvidence(
    result: Extract<AllowanceValidationResult, { readonly ok: true }> | undefined,
    failure: ProviderFailure | null,
  ): Promise<void> {
    const { writeAllowanceEvidence } = await import("../../evidence/allowance-evidence-recorder.ts");
    await writeAllowanceEvidence({ schemaVersion: 1, runId: this.#runId(), correlationId: result?.correlationId ?? failure?.correlationId ?? this.#correlationId(),
      result: failure ? "reject" : "proceed", runtimeVersion: result?.runtimeVersion ?? null,
      providerReadiness: result?.providerReadiness ?? "temporarily_unavailable", buckets: result?.buckets ?? [], remedy: result?.remedy ?? null,
      failureCode: failure?.code ?? null, reproductionCommand: ALLOWANCE_REPRODUCTION_COMMAND }, this.#evidenceRoot);
  }

  async #recordAuthenticationFailure(failure: ProviderFailure): Promise<ProviderFailure> {
    if (failure.code === "evidence_write_failed") return failure;
    try {
      await writeAuthenticationEvidence({
        schemaVersion: 1,
        runId: this.#runId(),
        correlationId: failure.correlationId,
        result: "reject",
        authenticationState: null,
        planCategory: "unknown",
        expectedPro: "unknown",
        deviceCodeCapability: "unsupported",
        logoutOutcome: "not_needed",
        profileIsolation: "not_completed",
        credentialOwnership: "rejected",
        retryable: false,
        failureCode: failure.code,
        reproductionCommand: AUTH_REPRODUCTION_COMMAND,
      }, this.#evidenceRoot);
      return failure;
    } catch {
      return createProviderFailure({
        code: "evidence_write_failed",
        correlationId: failure.correlationId,
        remediation: { action: "check_permissions", reference: "evidence_directory" },
      });
    }
  }

  async #recordAuthenticationRejection(
    result: Extract<AuthenticationValidationResult, { readonly ok: true }>,
    rejection: { readonly code: ProviderFailure["code"]; readonly retryable: boolean; readonly remediation: ProviderFailure["remediation"] },
  ): Promise<ProviderFailure> {
    const failure = createProviderFailure({
      code: rejection.code,
      correlationId: result.correlationId,
      remediation: rejection.remediation,
    });
    try {
      await writeAuthenticationEvidence({
        schemaVersion: 1,
        runId: this.#runId(),
        correlationId: result.correlationId,
        result: "reject",
        authenticationState: result.authenticationState,
        planCategory: result.planCategory,
        expectedPro: result.expectedPro,
        deviceCodeCapability: result.deviceCodeCapability,
        logoutOutcome: result.logoutOutcome,
        profileIsolation: result.profileIsolation,
        credentialOwnership: result.credentialOwnership,
        retryable: rejection.retryable,
        failureCode: rejection.code,
        reproductionCommand: AUTH_REPRODUCTION_COMMAND,
      }, this.#evidenceRoot);
      return failure;
    } catch {
      return createProviderFailure({
        code: "evidence_write_failed",
        correlationId: result.correlationId,
        remediation: { action: "check_permissions", reference: "evidence_directory" },
      });
    }
  }

  async #runAttempt(
    context: AttemptContext,
    generation: 1 | 2,
    authentication?: { readonly interactive: boolean; readonly timeoutMs: number; readonly deviceCodeRecovery: boolean; result: { result?: AuthenticationExchangeResult } },
    allowance?: { readonly timeoutMs: number; result: { result?: AllowanceExchangeResult } },
  ): Promise<AttemptState> {
    const attemptId = `attempt-${generation}-${randomUUID()}`;
    const correlationId = attemptCorrelation(context.correlationId, attemptId);
    let discovery: ExecutableDiscoveryResult | undefined;
    let profile: IsolatedRuntimeProfile | undefined;
    let snapshot: ExecutableSnapshot | undefined;
    let compatibility: SnapshotCompatibilityResult | undefined;
    let supervisor: AppServerSupervisorResult | undefined;
    let failure: ProviderFailure | undefined;
    let isolationComparison: PrivateRunEvidence["isolationComparison"] = "not_completed";

    try {
      discovery = await this.#discover({
        ...(context.request.path ? { path: context.request.path } : {}),
        ...(context.request.executableName
          ? { executableName: context.request.executableName }
          : {}),
      });
      if (!discovery.ok) {
        failure = withCorrelation(discovery, correlationId);
      } else {
        profile = await this.#createProfile({
          baseDirectory: join(context.fixtureRoot, "runs"),
          normalProfileRoot: context.normalProfile,
          ...(context.request.certificateConfiguration
            ? { certificateConfiguration: context.request.certificateConfiguration }
            : {}),
        });
        try {
          snapshot = await createExecutableSnapshot({
            sourcePath: discovery.executablePath,
            instanceDirectory: profile.runtimeRoot,
          });
        } catch {
          failure = createProviderFailure({
            code: "runtime_snapshot_failed",
            correlationId,
            remediation: { action: "inspect_local_evidence", reference: "runtime_snapshot" },
            compatibilityStatus: "incompatible",
            diagnosticReference: diagnosticReference(correlationId),
          });
        }
        if (snapshot) {
          compatibility = await validateSnapshotCompatibility({
            attemptId,
            snapshot,
            manifestPath: this.#manifestPath,
            environment: profile.childEnvironment,
            workingDirectory: profile.workingDirectory,
            stagingDirectory: join(profile.runtimeRoot, "protocol-generated"),
            versionTimeoutMs: 2_000,
            generatorTimeoutMs: 5_000,
            generatorShutdownStepMs: 500,
          });
          if (!compatibility.ok) {
            failure = compatibilityFailure(compatibility, correlationId);
          } else if (authentication?.deviceCodeRecovery === true &&
            compatibility.deviceCodeRecoverySupported !== true) {
            failure = createProviderFailure({
              code: "authentication_unsupported", correlationId,
              remediation: { action: "sign_in_with_chatgpt", reference: "device_code_unsupported" },
            });
          } else {
            supervisor = await superviseCodexAppServer({
              workingDirectory: profile.workingDirectory,
              environment: profile.childEnvironment,
              initializationTimeoutMs: context.request.initializationTimeoutMs ?? 5_000,
              shutdownTimeoutMs: context.request.shutdownTimeoutMs ?? 500,
              correlationId,
              attemptId,
              compatibility: compatibility.capability,
              ...(authentication ? {
                authenticationMode: true,
                postInitializeCheck: async (connection) => {
                  authentication.result.result = await connection.validateManagedChatgptAuthentication({
                    interactive: authentication.interactive,
                    timeoutMs: authentication.timeoutMs,
                    ...(authentication.deviceCodeRecovery ? { deviceCodeRecovery: true } : {}),
                    ...(this.#openLoginUrl ? { openLoginUrl: this.#openLoginUrl } : {}),
                  });
                },
              } : allowance ? {
                allowanceMode: true,
                postInitializeCheck: async (connection) => { allowance.result.result = await connection.readAllowance(allowance.timeoutMs); },
              } : {}),
            });
            if (!supervisor.ok) failure = supervisor;
          }
        }
      }

      await assertFixtureUnchanged(
        context.normalProfileBefore,
        await snapshotFixture(context.normalProfile),
      );
      if (!isAlive(context.sentinel.pid)) throw new Error("isolation_failed");
      isolationComparison = "unchanged";
    } catch {
      isolationComparison = profile ? "changed" : "not_completed";
      failure = createProviderFailure({
        code: "isolation_failed",
        correlationId,
        remediation: { action: "check_permissions", reference: "isolated_runtime" },
        diagnosticReference: diagnosticReference(correlationId),
      });
    }

    return Object.freeze({
      attemptId,
      correlationId,
      discovery,
      profile,
      snapshot,
      compatibility,
      supervisor,
      failure,
      underlyingFailure: undefined,
      isolationComparison,
    });
  }
}

function createProtocolEvidencePackage(
  runId: string,
  correlationId: string,
  attempts: readonly AttemptState[],
  failure: ProviderFailure | undefined,
  restartRequested: boolean,
): ProtocolEvidencePackage {
  const privateAttempts = attempts.map((attempt, index) =>
    createPrivateProtocolAttempt(attempt, (index + 1) as 1 | 2),
  );
  const attachments: ProtocolEvidenceAttachment[] = [];
  for (const [index, attempt] of attempts.entries()) {
    const generated = generatedSchemas(attempt.compatibility);
    if (!generated) continue;
    const generation = index + 1;
    attachments.push(
      Object.freeze({
        kind: "json" as const,
        sourceDirectory: generated.jsonDirectory,
        destinationRelativePath: `protocol-schemas/attempt-${generation}/json`,
        expectedBundle: generated.jsonBundle,
      }),
      Object.freeze({
        kind: "typescript" as const,
        sourceDirectory: generated.typescriptDirectory,
        destinationRelativePath: `protocol-schemas/attempt-${generation}/typescript`,
        expectedBundle: generated.typescriptBundle,
      }),
    );
  }
  return Object.freeze({
    privateEvidence: Object.freeze({
      schemaVersion: PROTOCOL_EVIDENCE_SCHEMA_VERSION,
      runId,
      correlationId,
      result: failure ? "failed" : "passed",
      failureCode: failure?.code ?? null,
      reproductionCommand: restartRequested
        ? PROTOCOL_RESTART_REPRODUCTION_COMMAND
        : PROTOCOL_REPRODUCTION_COMMAND,
      attempts: Object.freeze(privateAttempts),
    }),
    attachments: Object.freeze(attachments),
  });
}

function createPrivateProtocolAttempt(
  attempt: AttemptState,
  generation: 1 | 2,
): PrivateProtocolAttemptEvidence {
  const compatibility = attempt.compatibility;
  const manifest = compatibility?.ok ? compatibility.manifest : compatibility?.manifest;
  const manifestDigest = compatibility?.ok
    ? compatibility.manifestDigest
    : compatibility?.manifestDigest;
  const generated = generatedSchemas(compatibility);
  const generationAttempted = compatibility?.ok || compatibility?.generationAttempted === true;
  const schemaRoot = attempt.profile ? join(attempt.profile.runtimeRoot, "protocol-generated") : null;
  const detectedMethods = compatibility?.detectedMethods;
  return Object.freeze({
    generation,
    attemptId: attempt.attemptId,
    correlationId: attempt.correlationId,
    failureCode: attempt.failure?.code ?? null,
    underlyingFailureCode: attempt.underlyingFailure?.code ?? null,
    scope: attempt.isolationComparison === "changed" ? "concurrent_instance" : null,
    compatibilityOutcome: compatibility?.ok ? "compatible" : compatibility ? "incompatible" : "not_checked",
    detectedBuild: compatibility?.detectedBuild ?? null,
    platform: process.platform,
    architecture: process.arch,
    binaryContentSha256: attempt.snapshot?.binaryContentSha256 ?? null,
    manifestId: manifest?.manifestId ?? null,
    manifestDigest: manifestDigest ?? null,
    manifest: manifest ?? null,
    resolvedExecutablePath: attempt.discovery?.ok ? attempt.discovery.executablePath : null,
    snapshotExecutablePath: attempt.snapshot?.executablePath ?? null,
    jsonSchemaDirectory: generationAttempted && schemaRoot ? join(schemaRoot, "json") : null,
    typescriptSchemaDirectory: generationAttempted && schemaRoot ? join(schemaRoot, "typescript") : null,
    exactJsonArgv: generationAttempted && attempt.snapshot && schemaRoot
      ? [attempt.snapshot.executablePath, "app-server", "generate-json-schema", "--out", join(schemaRoot, "json")]
      : null,
    exactTypescriptArgv: generationAttempted && attempt.snapshot && schemaRoot
      ? [attempt.snapshot.executablePath, "app-server", "generate-ts", "--out", join(schemaRoot, "typescript")]
      : null,
    schemas: generated ? Object.freeze({
      json: generated.jsonBundle,
      typescript: generated.typescriptBundle,
    }) : null,
    requiredMethods: manifest?.requiredMethods ?? null,
    detectedMethods: detectedMethods ?? null,
    enabledDispatch: manifest?.enabledDispatch ?? null,
    lifecycle: attempt.supervisor?.lifecycle ?? defaultFailureLifecycle(attempt.discovery),
    shutdownOutcome: attempt.supervisor?.shutdownOutcome ?? "not_started",
    preflightProcessGroupsReaped: compatibility?.ownedProcessesReaped ?? null,
    processOwnership: attempt.supervisor
      ? Object.freeze({
          childPid: attempt.supervisor.childPid,
          processGroupId: attempt.supervisor.processGroupId,
          reaped: attempt.supervisor.processGroupReaped,
        })
      : null,
    diagnosticReference: attempt.failure
      ? attempt.failure.diagnosticReference ?? diagnosticReference(attempt.correlationId)
      : null,
    transcript: attempt.supervisor?.transcript ?? [],
  });
}

function generatedSchemas(
  compatibility: SnapshotCompatibilityResult | undefined,
) {
  return compatibility?.ok ? compatibility.generated : compatibility?.generated;
}

function withRestartFailure(attempt: AttemptState): AttemptState {
  const underlying = attempt.failure;
  return Object.freeze({
    ...attempt,
    underlyingFailure: underlying,
    failure: createProviderFailure({
      code: "restart_failed",
      correlationId: attempt.correlationId,
      remediation: { action: "inspect_local_evidence", reference: underlying?.code ?? "restart" },
      compatibilityStatus: "incompatible",
      ...(underlying?.detectedBuild ? { detectedBuild: underlying.detectedBuild } : {}),
      ...(underlying?.supportedBuild ? { supportedBuild: underlying.supportedBuild } : {}),
      diagnosticReference: diagnosticReference(attempt.correlationId),
    }),
  });
}

function restartIsSafe(attempt: AttemptState): boolean {
  if (attempt.compatibility?.ownedProcessesReaped === false) return false;
  if (!attempt.supervisor) return true;
  if (["shutdown_timeout", "shutdown_failed"].includes(attempt.failure?.code ?? "")) return false;
  return (
    attempt.supervisor.processGroupReaped &&
    attempt.supervisor.shutdownOutcome !== "shutdown_failure"
  );
}

function failedAttempt(
  attemptId: string,
  correlationId: string,
  failure: ProviderFailure,
): AttemptState {
  return Object.freeze({
    attemptId,
    correlationId,
    discovery: undefined,
    profile: undefined,
    snapshot: undefined,
    compatibility: undefined,
    supervisor: undefined,
    failure,
    underlyingFailure: undefined,
    isolationComparison: "not_completed",
  });
}

function attemptCorrelation(runCorrelationId: string, attemptId: string): string {
  return `${runCorrelationId}:${attemptId}`;
}

function compatibilityFailure(
  compatibility: Extract<SnapshotCompatibilityResult, { readonly ok: false }>,
  correlationId: string,
): ProviderFailure {
  const code = compatibilityFailureCode(compatibility.reason);
  return createProviderFailure({
    code,
    correlationId,
    remediation: {
      action: ["unsupported_runtime_build", "protocol_binary_mismatch"].includes(code)
        ? "repair_runtime"
        : "inspect_local_evidence",
      reference: code,
    },
    compatibilityStatus: "incompatible",
    ...(compatibility.detectedBuild ? { detectedBuild: compatibility.detectedBuild } : {}),
    ...(compatibility.supportedBuild ? { supportedBuild: compatibility.supportedBuild } : {}),
    diagnosticReference: diagnosticReference(correlationId),
  });
}

function compatibilityFailureCode(
  reason: SnapshotCompatibilityFailureReason,
): ProviderFailure["code"] {
  switch (reason) {
    case "unsupported_build":
    case "unsupported_platform":
    case "unsupported_architecture":
      return "unsupported_runtime_build";
    case "binary_mismatch":
      return "protocol_binary_mismatch";
    case "invalid_manifest":
      return "invalid_protocol_manifest";
    case "schema_generation_failed":
      return "schema_generation_failed";
    case "schema_mismatch":
      return "protocol_schema_mismatch";
    case "missing_required_method":
      return "missing_required_method";
    case "unsupported_dispatch":
      return "unsupported_dispatch";
    case "runtime_terminated":
      return "runtime_terminated_during_checking";
  }
}

function authenticationRejection(
  result: AuthenticationExchangeResult,
): { readonly code: ProviderFailure["code"]; readonly retryable: boolean; readonly remediation: ProviderFailure["remediation"] } | undefined {
  if (
    result.state === "authenticated_chatgpt" &&
    result.planCategory === "pro" &&
    result.expectedPro === "matched" &&
    result.logoutOutcome === "completed" &&
    !result.preexistingAuthentication
  ) {
    return undefined;
  }
  switch (result.state) {
    case "cancelled":
      return { code: "authentication_cancelled", retryable: true, remediation: { action: "retry_validation", reference: "cancelled" } };
    case "expired":
      return { code: "authentication_expired", retryable: true, remediation: { action: "retry_validation", reference: "expired" } };
    case "secure_storage_unavailable":
      return { code: "secure_storage_unavailable", retryable: true, remediation: { action: "repair_secure_storage", reference: "secure_storage" } };
    case "signed_out":
      return { code: "authentication_failed", retryable: true, remediation: { action: "sign_in_with_chatgpt", reference: "signed_out" } };
    case "authenticated_chatgpt":
      return {
        code: "authentication_failed",
        retryable: !result.preexistingAuthentication,
        remediation: {
          action: result.preexistingAuthentication ? "inspect_local_evidence" : "sign_in_with_chatgpt",
          reference: result.preexistingAuthentication ? "preexisting_disposable_profile" : "subscription_not_pro",
        },
      };
    case "failed":
      return { code: "authentication_failed", retryable: true, remediation: { action: "retry_validation", reference: "failed" } };
  }
}

function withCorrelation(failure: ProviderFailure, correlationId: string): ProviderFailure {
  return createProviderFailure({
    code: failure.code,
    correlationId,
    remediation: failure.remediation,
    diagnosticReference: diagnosticReference(correlationId),
  });
}

function defaultFailureLifecycle(
  discovery: ExecutableDiscoveryResult | undefined,
): readonly LifecyclePhase[] {
  return discovery?.ok ? ["undiscovered", "discovered", "failed"] : ["undiscovered", "failed"];
}

function diagnosticReference(correlationId: string): string {
  return `protocol-${Buffer.from(correlationId).toString("base64url").slice(0, 24)}`;
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
