import assert from "node:assert/strict";
import test from "node:test";
import { createJobOutcomeState, reduceJobOutcome } from "../src/core/job-outcome-reducer.ts";

const event = (kind: Parameters<typeof reduceJobOutcome>[1]["kind"], sequence: number, overrides: Partial<Parameters<typeof reduceJobOutcome>[1]> = {}) => ({ eventId: `e-${sequence}-${kind}`, providerInstanceId: "provider-a", jobId: "job-a", attempt: 1, sequence, kind, ...overrides });

test("reducer gives a durable job exactly one terminal result across duplicate, late, and cancellation races", () => {
  let state = createJobOutcomeState("job-a", "provider-a");
  state = reduceJobOutcome(state, event("cancel_requested", 1));
  state = reduceJobOutcome(state, event("completed", 2, { diagnosticReference: "d-complete" }));
  state = reduceJobOutcome(state, event("cancel_acknowledged", 3));
  state = reduceJobOutcome(state, event("completed", 2, { diagnosticReference: "d-complete" }));
  assert.deepEqual(state.terminal, { jobId: "job-a", providerInstanceId: "provider-a", attempt: 1, outcome: "completed", diagnosticReference: "d-complete" });
  assert.equal(Object.isFrozen(state.terminal), true);
});

test("reducer ignores cross-job and stale events while retry makes a newer attempt authoritative", () => {
  let state = createJobOutcomeState("job-a", "provider-a");
  state = reduceJobOutcome(state, event("failed", 1, { jobId: "other" }));
  state = reduceJobOutcome(state, event("retry", 2, { attempt: 2 }));
  state = reduceJobOutcome(state, event("failed", 3)); // stale attempt one
  state = reduceJobOutcome(state, event("child_died", 3, { attempt: 2 }));
  assert.equal(state.attempt, 2);
  assert.equal(state.terminal?.outcome, "child_died");
});
