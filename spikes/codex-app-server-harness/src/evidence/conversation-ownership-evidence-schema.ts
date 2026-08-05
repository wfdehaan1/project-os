/** Structural-only export/restore evidence. Values intentionally contain no IDs or content. */
export interface ConversationOwnershipEvidence {
  readonly schemaVersion: 1;
  readonly runId: string;
  readonly correlationId: string;
  readonly outcome: "proceed" | "reject";
  readonly exportDigest: string | null;
  readonly restoreDigest: string | null;
  readonly counts: Readonly<Record<"projects" | "conversations" | "transcriptEntries" | "acceptedHistoryEntries" | "rationales" | "provenances" | "sources" | "relationships", number>>;
  readonly checks: readonly ("binding_excluded" | "offline_restore" | "remap_complete" | "fresh_binding_required")[];
  readonly stopConditions: readonly string[];
  readonly reproductionCommand: "npm run validate:conversation-ownership";
}
