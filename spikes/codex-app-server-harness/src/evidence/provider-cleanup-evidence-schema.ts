/** Aggregate-only evidence for the offline cleanup state-machine proof. */
export interface ProviderCleanupEvidence {
  readonly schemaVersion: 1;
  readonly runId: string;
  readonly correlationId: string;
  readonly decision: "reject";
  readonly counts: Readonly<Record<"created" | "confirmed" | "absent" | "pending" | "reauthRequired" | "ledgerGaps" | "rolloutMetadata", number>>;
  readonly checks: readonly ("intent_before_create" | "crash_reconciliation" | "local_erasure_separate" | "managed_metadata_removed" | "sanitized_aggregate")[];
  readonly stopConditions: readonly ("live_codex_cleanup_unproven" | "containment_boundary_unavailable")[];
  readonly reproductionCommand: "npm run validate:provider-cleanup";
}
