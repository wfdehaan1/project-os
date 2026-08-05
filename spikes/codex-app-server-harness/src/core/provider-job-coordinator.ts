import type { ChangeProposal } from "./change-proposal-schema.ts";
import type { StructuredOutputTerminalResult } from "./structured-output.ts";
import { freezeTerminal } from "./structured-output.ts";

export interface PendingValidationProposal { readonly jobId: string; readonly attempt: number; readonly proposal: ChangeProposal; }
export interface StructuredJobState { readonly jobId: string; readonly attempt: number; readonly terminal: StructuredOutputTerminalResult | null; readonly pendingProposal: PendingValidationProposal | null; }
/** At most one immutable result/proposal for the active attempt; stale and duplicate completions are no-ops. */
export function coordinateStructuredCompletion(state: StructuredJobState, input: { readonly jobId: string; readonly attempt: number; readonly result: StructuredOutputTerminalResult }): StructuredJobState {
  if (state.terminal !== null || input.jobId !== state.jobId || input.attempt !== state.attempt) return state;
  const terminal = freezeTerminal(input.result);
  const pendingProposal = terminal.outcome === "accepted" ? Object.freeze({ jobId: state.jobId, attempt: state.attempt, proposal: terminal.proposal }) : null;
  return Object.freeze({ ...state, terminal, pendingProposal });
}
export function createStructuredJobState(jobId: string, attempt = 1): StructuredJobState { return Object.freeze({ jobId, attempt, terminal: null, pendingProposal: null }); }
