export type JobTerminalOutcome = "completed" | "failed" | "cancelled" | "timed_out" | "child_died";
export interface DurableJobEvent {
  readonly eventId: string;
  readonly providerInstanceId: string;
  readonly jobId: string;
  readonly attempt: number;
  readonly sequence: number;
  readonly kind: "completed" | "failed" | "cancel_requested" | "cancel_acknowledged" | "timed_out" | "child_died" | "retry";
  readonly diagnosticReference?: string;
}
export interface TerminalJobResult {
  readonly jobId: string;
  readonly providerInstanceId: string;
  readonly attempt: number;
  readonly outcome: JobTerminalOutcome;
  readonly diagnosticReference: string | null;
}
export interface JobOutcomeState {
  readonly jobId: string;
  readonly providerInstanceId: string;
  readonly attempt: number;
  readonly highestSequence: number;
  readonly seenEventIds: readonly string[];
  readonly cancellationRequested: boolean;
  readonly terminal: TerminalJobResult | null;
}

/** Pure, event-sourced reducer; unknown/cross-job/stale events are intentionally no-ops. */
export function reduceJobOutcome(state: JobOutcomeState, event: DurableJobEvent): JobOutcomeState {
  if (event.jobId !== state.jobId || event.providerInstanceId !== state.providerInstanceId ||
    state.seenEventIds.includes(event.eventId) || event.attempt < state.attempt ||
    (event.attempt === state.attempt && event.sequence <= state.highestSequence)) return state;
  // A job's terminal outcome is immutable. A new attempt must be authorized before terminality.
  if (state.terminal !== null) return state;
  if (event.kind === "retry") {
    if (event.attempt <= state.attempt) return state;
    return freezeState({ ...state, attempt: event.attempt, highestSequence: event.sequence, cancellationRequested: false, terminal: null, seenEventIds: append(state, event.eventId) });
  }
  if (event.attempt !== state.attempt) return state;
  const next = { ...state, highestSequence: event.sequence, seenEventIds: append(state, event.eventId) };
  if (event.kind === "cancel_requested") return freezeState({ ...next, cancellationRequested: true });
  const outcome = event.kind === "cancel_acknowledged" ? "cancelled" : event.kind === "completed" ? "completed" : event.kind === "failed" ? "failed" : event.kind === "timed_out" ? "timed_out" : event.kind === "child_died" ? "child_died" : null;
  if (!outcome) return freezeState(next);
  return freezeState({ ...next, terminal: Object.freeze({ jobId: state.jobId, providerInstanceId: state.providerInstanceId, attempt: state.attempt, outcome, diagnosticReference: event.diagnosticReference ?? null }) });
}

export function createJobOutcomeState(jobId: string, providerInstanceId: string, attempt = 1): JobOutcomeState {
  return freezeState({ jobId, providerInstanceId, attempt, highestSequence: 0, seenEventIds: [], cancellationRequested: false, terminal: null });
}
function append(state: JobOutcomeState, eventId: string): readonly string[] { return Object.freeze([...state.seenEventIds, eventId]); }
function freezeState(state: JobOutcomeState): JobOutcomeState { return Object.freeze({ ...state, seenEventIds: Object.freeze([...state.seenEventIds]), terminal: state.terminal ? Object.freeze({ ...state.terminal }) : null }); }
