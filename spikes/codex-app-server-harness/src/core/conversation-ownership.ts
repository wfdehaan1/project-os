/**
 * ProjectOS, rather than an AI runtime, owns the canonical conversation.  The
 * binding is deliberately a small, replaceable side-car and is never allowed
 * to carry or alter conversation content.
 */
export interface ConversationTranscriptEntry {
  readonly id: string;
  readonly role: "user" | "assistant" | "system";
  readonly text: string;
  readonly version: number;
}

export interface AcceptedHistoryEntry {
  readonly id: string;
  readonly transcriptEntryId: string;
  readonly acceptedAt: string;
}

export interface Conversation {
  readonly id: string;
  readonly version: number;
  readonly transcript: readonly ConversationTranscriptEntry[];
  readonly acceptedHistory: readonly AcceptedHistoryEntry[];
}

/** An adapter-owned opaque handle; it is intentionally not a conversation ID. */
export interface ProviderSessionBinding {
  readonly adapterId: string;
  readonly conversationId: string;
  readonly contextPreviewId: string;
  readonly opaqueSessionHandle: string;
}

const contextPreviewApprovalBrand: unique symbol = Symbol("projectos.context-preview-approval");
export interface ContextPreviewApproval { readonly [contextPreviewApprovalBrand]: true; }
interface ContextPreviewApprovalFacts { readonly conversationId: string; readonly contextPreviewId: string; consumed: boolean; }
const approvals = new WeakMap<object, ContextPreviewApprovalFacts>();

export type ResumeDecision =
  | Readonly<{ readonly kind: "resume"; readonly conversation: Conversation; readonly binding: ProviderSessionBinding }>
  | Readonly<{ readonly kind: "fresh_binding_required"; readonly conversation: Conversation; readonly reason: "missing" | "stale" | "wrong_adapter" | "wrong_conversation" }>;

export function createConversation(input: Conversation): Conversation {
  if (!record(input) || !exactKeys(input, ["acceptedHistory", "id", "transcript", "version"]) || !isSafeId(input.id) || !positiveVersion(input.version) || !Array.isArray(input.transcript) || !Array.isArray(input.acceptedHistory)) {
    throw new Error("conversation_invalid");
  }
  const transcriptIds = new Set<string>();
  const transcript = input.transcript.map((entry) => {
    if (!isTranscriptEntry(entry) || transcriptIds.has(entry.id)) throw new Error("conversation_invalid");
    transcriptIds.add(entry.id);
    return Object.freeze({ ...entry });
  });
  const acceptedIds = new Set<string>();
  const acceptedHistory = input.acceptedHistory.map((entry) => {
    if (!isAcceptedEntry(entry) || acceptedIds.has(entry.id) || !transcriptIds.has(entry.transcriptEntryId)) throw new Error("conversation_invalid");
    acceptedIds.add(entry.id);
    return Object.freeze({ ...entry });
  });
  return Object.freeze({ id: input.id, version: input.version, transcript: Object.freeze(transcript), acceptedHistory: Object.freeze(acceptedHistory) });
}

/** Mints the one-use application approval consumed when a provider binding is created. */
export function approveContextPreview(input: { readonly conversation: Conversation; readonly contextPreviewId: string }): ContextPreviewApproval {
  if (!isConversation(input.conversation) || !isSafeId(input.contextPreviewId)) throw new Error("context_preview_invalid");
  const approval = Object.freeze({}) as ContextPreviewApproval;
  approvals.set(approval, { conversationId: input.conversation.id, contextPreviewId: input.contextPreviewId, consumed: false });
  return approval;
}

/** A binding can only be created by consuming an explicit ProjectOS approval. */
export function createFreshProviderSessionBinding(input: {
  readonly conversation: Conversation;
  readonly adapterId: string;
  readonly opaqueSessionHandle: string;
  readonly approval: ContextPreviewApproval;
}): ProviderSessionBinding {
  const facts = typeof input.approval === "object" && input.approval !== null ? approvals.get(input.approval) : undefined;
  if (!isConversation(input.conversation) || !isAdapterId(input.adapterId) || !isOpaqueHandle(input.opaqueSessionHandle) || !facts || facts.consumed || facts.conversationId !== input.conversation.id) {
    throw new Error("binding_invalid");
  }
  facts.consumed = true;
  return Object.freeze({ adapterId: input.adapterId, conversationId: input.conversation.id, contextPreviewId: facts.contextPreviewId, opaqueSessionHandle: input.opaqueSessionHandle });
}

/** The named entry point makes the Context Preview approval requirement explicit. */
export function createFreshContextPreviewBinding(input: {
  readonly conversation: Conversation;
  readonly adapterId: string;
  readonly opaqueSessionHandle: string;
  readonly approval: ContextPreviewApproval;
}): ProviderSessionBinding {
  return createFreshProviderSessionBinding(input);
}

/**
 * A process restart never makes the adapter record authoritative.  A failed
 * match only drops the binding decision; callers retain the exact frozen local
 * Conversation instance.
 */
export function decideConversationResume(input: {
  readonly conversation: Conversation;
  readonly binding: ProviderSessionBinding | null;
  readonly adapterId: string;
  readonly bindingState?: "available" | "stale";
}): ResumeDecision {
  if (!isConversation(input.conversation) || !isAdapterId(input.adapterId)) throw new Error("conversation_invalid");
  if (input.binding === null) return fresh(input.conversation, "missing");
  if (!isBinding(input.binding)) return fresh(input.conversation, "stale");
  if (input.binding.conversationId !== input.conversation.id) return fresh(input.conversation, "wrong_conversation");
  if (input.binding.adapterId !== input.adapterId) return fresh(input.conversation, "wrong_adapter");
  if (input.bindingState !== undefined && input.bindingState !== "available" && input.bindingState !== "stale") return fresh(input.conversation, "stale");
  if (input.bindingState === "stale") return fresh(input.conversation, "stale");
  return Object.freeze({ kind: "resume", conversation: input.conversation, binding: input.binding });
}

export function isSafeId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z][A-Za-z0-9._-]{0,127}$/u.test(value);
}

export function isConversation(value: unknown): value is Conversation {
  try { createConversation(value as Conversation); return true; } catch { return false; }
}

export function isBinding(value: unknown): value is ProviderSessionBinding {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  const candidate = value as Record<string, unknown>;
  return exactKeys(candidate, ["adapterId", "contextPreviewId", "conversationId", "opaqueSessionHandle"]) && isAdapterId(candidate.adapterId) && isSafeId(candidate.conversationId) && isSafeId(candidate.contextPreviewId) && isOpaqueHandle(candidate.opaqueSessionHandle);
}

function fresh(conversation: Conversation, reason: "missing" | "stale" | "wrong_adapter" | "wrong_conversation"): ResumeDecision {
  return Object.freeze({ kind: "fresh_binding_required", conversation, reason });
}
function isTranscriptEntry(value: unknown): value is ConversationTranscriptEntry { if (!record(value)) return false; return exactKeys(value, ["id", "role", "text", "version"]) && isSafeId(value.id) && (value.role === "user" || value.role === "assistant" || value.role === "system") && safeText(value.text) && positiveVersion(value.version); }
function isAcceptedEntry(value: unknown): value is AcceptedHistoryEntry { if (!record(value)) return false; return exactKeys(value, ["id", "transcriptEntryId", "acceptedAt"]) && isSafeId(value.id) && isSafeId(value.transcriptEntryId) && isTimestamp(value.acceptedAt); }
function record(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function exactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean { const keys = Object.keys(value).sort(); const sortedExpected = [...expected].sort(); return keys.length === sortedExpected.length && keys.every((key, index) => key === sortedExpected[index]); }
function positiveVersion(value: unknown): value is number { return typeof value === "number" && Number.isSafeInteger(value) && value > 0; }
function safeText(value: unknown): value is string { return typeof value === "string" && value.length > 0 && value.length <= 16_000 && !/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(value); }
function isTimestamp(value: unknown): value is string { if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u.test(value)) return false; const parsed = new Date(value); return !Number.isNaN(parsed.valueOf()) && parsed.toISOString() === value; }
function isAdapterId(value: unknown): value is string { return typeof value === "string" && /^[a-z][a-z0-9-]{0,63}$/u.test(value); }
function isOpaqueHandle(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$/u.test(value); }
