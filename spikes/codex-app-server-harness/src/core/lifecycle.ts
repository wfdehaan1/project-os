export const LIFECYCLE_PHASES = [
  "undiscovered",
  "discovered",
  "starting",
  "initializing",
  "initialized",
  "stopping",
  "stopped",
  "failed",
] as const;

export type LifecyclePhase = (typeof LIFECYCLE_PHASES)[number];

const nextPhase: Readonly<Partial<Record<LifecyclePhase, LifecyclePhase>>> = {
  undiscovered: "discovered",
  discovered: "starting",
  starting: "initializing",
  initializing: "initialized",
  initialized: "stopping",
  stopping: "stopped",
};

export class LifecycleTracker {
  readonly #history: LifecyclePhase[] = ["undiscovered"];

  get phase(): LifecyclePhase {
    return this.#history.at(-1) ?? "undiscovered";
  }

  get history(): readonly LifecyclePhase[] {
    return [...this.#history];
  }

  transition(phase: LifecyclePhase): boolean {
    if (nextPhase[this.phase] !== phase) return false;
    this.#history.push(phase);
    return true;
  }

  fail(): boolean {
    if (this.phase === "failed" || this.phase === "stopped") return false;
    this.#history.push("failed");
    return true;
  }
}
