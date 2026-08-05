/** Provider-neutral, safe representation. Provider wire shapes never cross this module boundary. */
export interface AllowanceBucket {
  readonly usedPercent: number;
  readonly windowDurationMinutes: number;
  readonly resetsAt: string | null;
  readonly reachedLimit: boolean;
}

export interface AllowanceRemedy {
  readonly action: "wait_for_allowance_reset";
  readonly resetsAt: string | null;
}

export interface NormalizedAllowance {
  readonly buckets: readonly AllowanceBucket[];
  readonly providerReadiness: "available" | "temporarily_unavailable";
  readonly remedy: AllowanceRemedy | null;
}

export function normalizeAllowanceBuckets(buckets: readonly AllowanceBucket[]): NormalizedAllowance {
  const immutable = Object.freeze(buckets.map((bucket) => Object.freeze({ ...bucket })));
  const exhausted = immutable.some((bucket) => bucket.reachedLimit);
  const reset = latestReachedReset(immutable);
  return Object.freeze({
    buckets: immutable,
    providerReadiness: exhausted ? "temporarily_unavailable" : "available",
    remedy: exhausted ? Object.freeze({ action: "wait_for_allowance_reset", resetsAt: reset }) : null,
  });
}

function latestReachedReset(buckets: readonly AllowanceBucket[]): string | null {
  const resets = buckets.flatMap((bucket) => bucket.reachedLimit && bucket.resetsAt ? [bucket.resetsAt] : []);
  return resets.length === 0 ? null : resets.reduce((latest, reset) => reset > latest ? reset : latest);
}
