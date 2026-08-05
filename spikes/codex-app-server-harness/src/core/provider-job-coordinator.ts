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

export interface DurableProviderJob {
  readonly jobId: string;
  readonly activeAttempt: number;
  readonly requiredCanonicalRevision: string;
  readonly state: StructuredJobState;
  readonly cancelled: boolean;
}

export interface CompletionInput {
  readonly jobId: string;
  readonly attempt: number;
  readonly canonicalRevision: string;
  readonly result: StructuredOutputTerminalResult;
}

/**
 * A deliberately small in-memory durable-job model for the spike. Every
 * transition is serialized per job and terminal entries leave the active
 * queue, so a stale retry cannot complete a replacement attempt.
 */
export class ProviderJobCoordinator {
  readonly #jobs = new Map<string, DurableProviderJob>();
  readonly #active = new Set<string>();
  readonly #tails = new Map<string, Promise<void>>();

  async create(jobId: string, requiredCanonicalRevision: string, attempt = 1): Promise<DurableProviderJob> {
    return this.#serialized(jobId, () => {
      const previous = this.#jobs.get(jobId);
      if (!safeId(jobId) || !safeId(requiredCanonicalRevision) || !Number.isSafeInteger(attempt) || attempt < 1 || this.#active.has(jobId) || (previous && attempt <= previous.activeAttempt)) throw new Error("duplicate_active_job");
      const job = freezeJob({ jobId, activeAttempt: attempt, requiredCanonicalRevision, state: createStructuredJobState(jobId, attempt), cancelled: false });
      this.#jobs.set(jobId, job); this.#active.add(jobId); return job;
    });
  }

  async complete(input: CompletionInput): Promise<DurableProviderJob | null> {
    return this.#serialized(input.jobId, () => {
      const current = this.#jobs.get(input.jobId);
      if (!current || !this.#active.has(input.jobId) || current.cancelled || current.activeAttempt !== input.attempt || current.requiredCanonicalRevision !== input.canonicalRevision) return null;
      const state = coordinateStructuredCompletion(current.state, { jobId: input.jobId, attempt: input.attempt, result: input.result });
      if (state === current.state) return null;
      const completed = freezeJob({ ...current, state });
      this.#jobs.set(input.jobId, completed); this.#active.delete(input.jobId);
      return completed;
    });
  }

  async cancel(jobId: string, attempt: number): Promise<DurableProviderJob | null> {
    return this.#serialized(jobId, () => {
      const current = this.#jobs.get(jobId);
      if (!current || !this.#active.has(jobId) || current.activeAttempt !== attempt) return null;
      const state = coordinateStructuredCompletion(current.state, { jobId, attempt, result: Object.freeze({ outcome: "reject", stopConditions: Object.freeze(["cancelled"]) }) });
      const cancelled = freezeJob({ ...current, cancelled: true, state });
      this.#jobs.set(jobId, cancelled); this.#active.delete(jobId);
      return cancelled;
    });
  }

  get(jobId: string): DurableProviderJob | null { return this.#jobs.get(jobId) ?? null; }
  activeJobIds(): readonly string[] { return Object.freeze([...this.#active].sort()); }

  async #serialized<T>(jobId: string, action: () => T): Promise<T> {
    const previous = this.#tails.get(jobId) ?? Promise.resolve();
    let release: (() => void) | undefined;
    const own = new Promise<void>((resolve) => { release = resolve; });
    const tail = previous.then(() => own);
    this.#tails.set(jobId, tail);
    await previous;
    try { return action(); }
    finally {
      release!();
      if (this.#tails.get(jobId) === tail) this.#tails.delete(jobId);
    }
  }
}

function freezeJob(value: DurableProviderJob): DurableProviderJob {
  return Object.freeze({ ...value, state: Object.freeze({ ...value.state }) });
}
function safeId(value: string): boolean { return /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/u.test(value); }
