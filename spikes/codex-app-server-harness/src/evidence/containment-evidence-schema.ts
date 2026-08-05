/** Sanitized structural evidence only: never paths, prompts, raw payloads, URLs, or identities. */
export interface ContainmentValidationEvidence {
  readonly schemaVersion: 1;
  readonly runId: string;
  readonly correlationId: string;
  readonly result: "proceed" | "reject";
  readonly runtimeFingerprint: string | null;
  readonly manifestFingerprint: string | null;
  readonly allowedReadRootCount: number;
  readonly writableRootCount: 0;
  readonly instructionSources: readonly ["projectos_context_preview"] | readonly [];
  readonly boundary: "stable_runtime_disable" | "verified_macos_boundary" | "unavailable";
  readonly observations: Readonly<Record<"allowed_read" | "outside_access" | "mutation" | "capability_effect", "observed" | "not_observed" | "not_run">>;
  readonly stopConditions: readonly string[];
  readonly reproductionCommand: "npm run validate:containment";
}
