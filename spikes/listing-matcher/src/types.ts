/**
 * The matcher's whole vocabulary. Deliberately small and free of any framework,
 * Node or DOM type: D19.3 says this module gets ported to Swift, and every type
 * here has a direct Swift equivalent (struct / enum / Optional).
 */

/** A listing as the extraction layer hands it over. Everything is optional except identity of the ad itself. */
export interface Listing {
  /** Capture id, for reporting only. */
  readonly id: string;
  /** Marketplace host, e.g. `autoscout24.nl`. */
  readonly site: string;
  /** The marketplace's own id for this ad. Unique per site, NOT per car. */
  readonly listingId: string | null;
  /** ISO 8601. Used to order a pair in time, which is what makes mileage direction readable. */
  readonly capturedAt: string | null;

  readonly plate: string | null;
  readonly make: string | null;
  readonly model: string | null;
  readonly variant: string | null;
  /** Seller-authored trim/spec line. Noisy free text, so it is tokenised rather than compared whole. */
  readonly trim: string | null;
  readonly body: string | null;
  /** ISO date of first registration, `YYYY-MM-DD`. */
  readonly firstRegistration: string | null;
  readonly mileageKm: number | null;
  readonly priceEur: number | null;
  readonly fuel: string | null;
  readonly transmission: string | null;
  readonly powerHp: number | null;
  readonly color: string | null;
  readonly upholstery: string | null;
  readonly doors: number | null;
  readonly sellerName: string | null;
  readonly sellerCity: string | null;
}

/**
 * Bands, per D5. `exact` merges silently; `probable` asks the user; `retained`
 * is treated as a new car but the comparison is kept so a later confirmation can
 * link them; `different` is dropped.
 */
export type Band = "exact" | "probable" | "retained" | "different";

export type Verdict = "agree" | "disagree" | "unknown";

/**
 * One feature's reading of a pair.
 *
 * `discriminating` is the field the confirmation UI cares about (D5): a feature
 * that separates *this* car from a lookalike, rather than one that merely repeats
 * what the search already narrowed. "Both are grey V60s" is agreement without
 * discrimination; "both read 129 720 km" is discrimination.
 */
export interface Evidence {
  readonly feature: string;
  readonly verdict: Verdict;
  /** Signed contribution to the raw score. Negative for `disagree`. */
  readonly contribution: number;
  /** Weight this feature could have contributed, had both sides carried the field. */
  readonly available: number;
  readonly discriminating: boolean;
  /** Human-readable, for the confirmation card and the eval report. */
  readonly note: string;
}

/** A hard reason to stop, regardless of how much else agrees. */
export interface Veto {
  readonly feature: string;
  readonly note: string;
}

export interface MatchResult {
  readonly band: Band;
  /** 0..1, share of *available* evidence weight that agrees. `null` when a hard key decided it. */
  readonly score: number | null;
  /** Set when the band came from a hard key rather than the score. */
  readonly hardKey: "listingId" | "plate" | null;
  readonly vetoes: readonly Veto[];
  readonly evidence: readonly Evidence[];
  /** Evidence worth putting on the confirmation card, strongest first. */
  readonly discriminators: readonly Evidence[];
}
