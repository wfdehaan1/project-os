import assert from "node:assert/strict";
import test from "node:test";

import { approveContextPreview, createConversation, createFreshContextPreviewBinding, createFreshProviderSessionBinding, decideConversationResume } from "../src/core/conversation-ownership.ts";

const conversation = createConversation({ id: "local-conversation", version: 1, transcript: [{ id: "local-entry", role: "user", text: "Local truth remains here.", version: 1 }], acceptedHistory: [{ id: "local-accepted", transcriptEntryId: "local-entry", acceptedAt: "2026-08-05T10:00:00.000Z" }] });

test("a binding is opaque, adapter-keyed metadata and does not replace the canonical Conversation ID", () => {
  const binding = createFreshProviderSessionBinding({ conversation, adapterId: "codex", opaqueSessionHandle: "opaque-123", approval: approveContextPreview({ conversation, contextPreviewId: "preview-1" }) });
  assert.equal(binding.conversationId, conversation.id);
  assert.notEqual(binding.opaqueSessionHandle, conversation.id);
  assert.equal(Object.isFrozen(conversation.transcript), true);
  assert.equal(Object.isFrozen(binding), true);
});

test("restart classification resets only missing, stale, wrong-adapter, and wrong-conversation bindings", () => {
  const binding = createFreshProviderSessionBinding({ conversation, adapterId: "codex", opaqueSessionHandle: "opaque-123", approval: approveContextPreview({ conversation, contextPreviewId: "preview-2" }) });
  assert.equal(decideConversationResume({ conversation, binding, adapterId: "codex" }).kind, "resume");
  for (const input of [
    { binding: null, adapterId: "codex", expected: "missing" },
    { binding, adapterId: "codex", bindingState: "stale" as const, expected: "stale" },
    { binding, adapterId: "other", expected: "wrong_adapter" },
    { binding: { ...binding, conversationId: "other-conversation" }, adapterId: "codex", expected: "wrong_conversation" },
  ]) {
    const decision = decideConversationResume({ conversation, binding: input.binding, adapterId: input.adapterId, ...(input.bindingState ? { bindingState: input.bindingState } : {}) });
    assert.equal(decision.kind, "fresh_binding_required");
    if (decision.kind === "fresh_binding_required") assert.equal(decision.reason, input.expected);
    assert.equal(decision.conversation, conversation);
  }
  const unknown = decideConversationResume({ conversation, binding, adapterId: "codex", bindingState: "unknown" as never });
  assert.equal(unknown.kind, "fresh_binding_required");
});

test("binding creation consumes an unforgeable Context Preview approval", () => {
  assert.throws(() => createFreshProviderSessionBinding({ conversation, adapterId: "codex", opaqueSessionHandle: "opaque-123", approval: {} as never }), /binding_invalid/u);
  const approval = approveContextPreview({ conversation, contextPreviewId: "preview-3" });
  const approved = createFreshContextPreviewBinding({ conversation, adapterId: "codex", opaqueSessionHandle: "opaque-preview-1", approval });
  assert.equal(approved.conversationId, conversation.id);
  assert.equal(approved.contextPreviewId, "preview-3");
  assert.throws(() => createFreshProviderSessionBinding({ conversation, adapterId: "codex", opaqueSessionHandle: "opaque-reused", approval }), /binding_invalid/u);
});

test("canonical Conversations reject provider fields and impossible timestamps", () => {
  assert.throws(() => createConversation({ ...conversation, providerSession: "forbidden" } as never), /conversation_invalid/u);
  assert.throws(() => createConversation({ ...conversation, acceptedHistory: [{ ...conversation.acceptedHistory[0]!, acceptedAt: "2026-02-30T10:00:00.000Z" }] }), /conversation_invalid/u);
});
