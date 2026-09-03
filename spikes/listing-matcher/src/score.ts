/**
 * Scoring and banding.
 *
 * Structure, in order of authority:
 *   1. Hard keys   — same listing id, or same plate. Decides `exact` outright.
 *   2. Vetoes      — facts no amount of agreement can outweigh.
 *   3. Weighted score over the features that both sides could answer.
 *   4. Same-seller adjustment — raises the bar for the D5 false positive.
 *
 * The score is `agreeing weight / available weight`, so a pair compared on four
 * fields is not punished against one compared on ten. That is what lets a thin
 * AutoTrack record match a rich AutoScout24 one.
 */
import { FEATURES, buildContext, toEvidence } from "./features.ts";
import { normalizePlate, sameText, sellerKey } from "./normalize.ts";
import type { Band, Evidence, Listing, MatchResult, Veto } from "./types.ts";

export interface Thresholds {
  /** At or above this, ask the user to confirm. */
  readonly probable: number;
  /** At or above this, treat as a new car but keep the comparison for later linking. */
  readonly retained: number;
  /**
   * Extra score demanded when both ads come from the same seller. A dealer
   * holding four near-identical cars is the realistic false positive, so the
   * same evidence has to work harder there.
   */
  readonly sameSellerPenalty: number;
}

/**
 * Recall-biased, per D5: a missed match costs the user a repeat of their own
 * research, a false suggestion costs one tap. These are the numbers the spike
 * exists to test — `evaluate.ts` sweeps them.
 */
export const DEFAULT_THRESHOLDS: Thresholds = {
  probable: 0.62,
  retained: 0.40,
  sameSellerPenalty: 0.12,
};

export interface MatchOptions {
  readonly thresholds?: Thresholds;
  /**
   * Ignore plate and listing id — as a match *and* as a veto. Both `same_car`
   * pairs in the corpus share a plate, and every negative pair carries two known
   * different plates, so with plates in play neither the scorer nor the
   * thresholds are ever exercised. Turning them off is how the spike measures
   * the part that is actually uncertain, and it models two real situations: a
   * site that does not publish the plate, and the pre-extraction provisional
   * match in D3.
   */
  readonly ignoreHardKeys?: boolean;
  /**
   * Skip veto banding, so the weighted score alone decides. Ablation only: it
   * answers "is the scoring function carrying any weight, or is it all vetoes?"
   * Vetoes are still computed and reported.
   */
  readonly ignoreVetoes?: boolean;
}

export function match(a: Listing, b: Listing, options: MatchOptions = {}): MatchResult {
  const thresholds = options.thresholds ?? DEFAULT_THRESHOLDS;
  const context = buildContext(a, b);

  const evidence: Evidence[] = FEATURES.map((feature) =>
    toEvidence(feature, feature.evaluate(context)),
  );
  const discriminators = evidence
    .filter((item) => item.discriminating && item.verdict !== "unknown")
    .sort((x, y) => Math.abs(y.contribution) - Math.abs(x.contribution));

  const hardKey = options.ignoreHardKeys === true ? null : findHardKey(a, b);
  if (hardKey !== null) {
    return { band: "exact", score: null, hardKey, vetoes: [], evidence, discriminators };
  }

  const vetoes = findVetoes(a, b, evidence, options.ignoreHardKeys === true);
  if (vetoes.length > 0 && options.ignoreVetoes !== true) {
    return { band: "different", score: 0, hardKey: null, vetoes, evidence, discriminators };
  }

  const score = rawScore(evidence);
  const sameSeller =
    sellerKey(a.sellerName) !== null && sellerKey(a.sellerName) === sellerKey(b.sellerName);
  const required = sameSeller
    ? { probable: thresholds.probable + thresholds.sameSellerPenalty, retained: thresholds.retained }
    : thresholds;

  const band: Band =
    score === null ? "different"
    : score >= required.probable ? "probable"
    : score >= required.retained ? "retained"
    : "different";

  return { band, score, hardKey: null, vetoes: [], evidence, discriminators };
}

function findHardKey(a: Listing, b: Listing): "listingId" | "plate" | null {
  // Same ad on the same site. Different sites can and do reuse id shapes, so the
  // site has to agree too.
  if (a.listingId !== null && a.listingId === b.listingId && a.site === b.site) return "listingId";
  const pa = normalizePlate(a.plate);
  const pb = normalizePlate(b.plate);
  if (pa !== null && pa === pb) return "plate";
  return null;
}

/**
 * Vetoes. Each is a fact that makes the pair a different car no matter what else
 * lines up — the guard against a recall-biased scorer merging a dealer's stock.
 */
function findVetoes(
  a: Listing,
  b: Listing,
  evidence: readonly Evidence[],
  ignoreHardKeys: boolean,
): Veto[] {
  const vetoes: Veto[] = [];

  // Two known, different plates is the cleanest negative in the corpus and the
  // exact inverse of the plate hard key — so it belongs to the hard-key layer
  // and has to disappear along with it.
  if (!ignoreHardKeys) {
    const pa = normalizePlate(a.plate);
    const pb = normalizePlate(b.plate);
    if (pa !== null && pb !== null && pa !== pb) {
      vetoes.push({ feature: "plate", note: `different plates (${a.plate} / ${b.plate})` });
    }
  }

  if (sameText(a.make, b.make) === false || sameText(a.model, b.model) === false) {
    vetoes.push({ feature: "makeModel", note: `${a.make} ${a.model} vs ${b.make} ${b.model}` });
  }

  const odometer = evidence.find((item) => item.feature === "mileage");
  if (odometer !== undefined && odometer.verdict === "disagree") {
    vetoes.push({ feature: "mileage", note: odometer.note });
  }

  return vetoes;
}

/** null when nothing could be compared at all. */
function rawScore(evidence: readonly Evidence[]): number | null {
  let available = 0;
  let earned = 0;
  for (const item of evidence) {
    available += item.available;
    earned += item.contribution;
  }
  if (available === 0) return null;
  // Map [-available, +available] onto [0, 1] so a pair that actively disagrees
  // lands near zero rather than at a misleading 0.5.
  return Math.max(0, Math.min(1, (earned / available + 1) / 2));
}
