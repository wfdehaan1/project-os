/**
 * The feature set.
 *
 * Each feature reads a pair and returns `agree`, `disagree` or `unknown`.
 * `unknown` is not a soft `disagree`: a field the extraction layer could not
 * reach must not push a pair away from a match, or every AutoTrack listing
 * (thin JSON-LD, no first registration, no seller) would score badly for
 * reasons that have nothing to do with the car. Unknown features are dropped
 * from the denominator instead — see `score.ts`.
 *
 * Weights are hand-set, not learned. With two positive pairs in the corpus
 * there is nothing to learn from; the point of the spike is to find out whether
 * a hand-set function is good enough to be worth learning later (D6 notes that
 * user confirmations and denials become the training signal).
 */
import type { Evidence, Listing, Verdict } from "./types.ts";
import {
  daysBetween, jaccard, monthsBetween, sameText, sellerKey, trimTokens,
} from "./normalize.ts";

export interface FeatureContext {
  readonly a: Listing;
  readonly b: Listing;
  /** `a` and `b` ordered by capture time, so mileage direction is readable. */
  readonly earlier: Listing;
  readonly later: Listing;
  readonly elapsedDays: number | null;
}

export interface Feature {
  readonly name: string;
  readonly weight: number;
  readonly evaluate: (context: FeatureContext) => FeatureReading;
}

export interface FeatureReading {
  readonly verdict: Verdict;
  readonly note: string;
  /**
   * 0..1 multiplier on the weight. Lets a feature express partial agreement
   * (trim overlap of 0.6) without needing a second weight.
   */
  readonly strength?: number;
  /** Overrides the default rule for what lands on the confirmation card. */
  readonly discriminating?: boolean;
}

const unknown = (note: string): FeatureReading => ({ verdict: "unknown", note });

/** Make and model. Cheap, and a mismatch is close to decisive — but see the veto in `score.ts`. */
const makeModel: Feature = {
  name: "makeModel",
  weight: 6,
  evaluate: ({ a, b }) => {
    const make = sameText(a.make, b.make);
    const model = sameText(a.model, b.model);
    if (make === null || model === null) return unknown("make or model missing");
    if (make && model) {
      // Everything in one search is the same make and model, so agreement here
      // narrows nothing. It is weight, not a discriminator.
      return { verdict: "agree", note: `both ${a.make} ${a.model}`, discriminating: false };
    }
    return { verdict: "disagree", note: `${a.make} ${a.model} vs ${b.make} ${b.model}` };
  },
};

/**
 * Trim overlap over the seller-authored spec line. Noisy: the same car relisted
 * by a different dealer gets a different line, and two different cars from one
 * dealer get near-identical lines. Weighted accordingly.
 */
const trim: Feature = {
  name: "trim",
  weight: 4,
  evaluate: ({ a, b }) => {
    const overlap = jaccard(trimTokens(a.trim), trimTokens(b.trim));
    if (overlap === null) return unknown("no trim tokens on one side");
    const pct = Math.round(overlap * 100);
    if (overlap >= 0.5) {
      return { verdict: "agree", strength: overlap, note: `trim tokens ${pct}% overlap` };
    }
    if (overlap <= 0.15) {
      return { verdict: "disagree", strength: 1 - overlap, note: `trim tokens only ${pct}% overlap` };
    }
    return { verdict: "unknown", note: `trim overlap ${pct}%, inconclusive` };
  },
};

/** First registration. A month-exact match is a strong discriminator; a year apart is decisive against. */
const firstRegistration: Feature = {
  name: "firstRegistration",
  weight: 8,
  evaluate: ({ a, b }) => {
    const months = monthsBetween(a.firstRegistration, b.firstRegistration);
    if (months === null) return unknown("first registration missing");
    if (months === 0) {
      return { verdict: "agree", note: `both first registered ${a.firstRegistration?.slice(0, 7)}`, discriminating: true };
    }
    // Sites occasionally disagree by a month on the same car (registration vs
    // delivery date), so one month is not yet evidence against.
    if (months <= 1) return { verdict: "unknown", note: `first registration ${months} month apart` };
    return { verdict: "disagree", note: `first registration ${months} months apart` };
  },
};

/** Engine power. Separates T4 from T5 from B3 where the trim line is ambiguous. */
const power: Feature = {
  name: "power",
  weight: 5,
  evaluate: ({ a, b }) => {
    if (a.powerHp === null || b.powerHp === null) return unknown("power missing");
    const delta = Math.abs(a.powerHp - b.powerHp);
    // Sites round kW→hp differently; 2 hp is noise, not a different engine.
    if (delta <= 2) return { verdict: "agree", note: `both ~${a.powerHp} hp` };
    return { verdict: "disagree", note: `${a.powerHp} hp vs ${b.powerHp} hp` };
  },
};

/**
 * Mileage — the feature D5 singles out, and the only one whose *direction*
 * carries meaning.
 *
 * Identical to the kilometre is the single best fuzzy signal in the corpus: two
 * ads for the same car snapshot the same odometer. Forward movement at a
 * plausible rate is confirming. Backward movement means a different car, or a
 * rolled-back odometer — either way, not a silent merge.
 */
const mileage: Feature = {
  name: "mileage",
  weight: 10,
  evaluate: ({ earlier, later, elapsedDays }) => {
    if (earlier.mileageKm === null || later.mileageKm === null) return unknown("mileage missing");
    const delta = later.mileageKm - earlier.mileageKm;
    if (delta === 0) {
      return {
        verdict: "agree",
        note: `identical odometer, ${later.mileageKm.toLocaleString("en-US")} km`,
        discriminating: true,
      };
    }
    if (delta < 0) {
      return {
        verdict: "disagree",
        note: `odometer runs backwards by ${(-delta).toLocaleString("en-US")} km`,
        discriminating: true,
      };
    }
    // A car on a forecourt does very few kilometres. Allow a generous 100 km/day
    // plus a 500 km floor for capture-time skew, then fall off.
    const budget = 500 + Math.max(0, elapsedDays ?? 0) * 100;
    if (delta <= budget) {
      return {
        verdict: "agree",
        strength: 1 - delta / (budget + 1),
        note: `odometer up ${delta.toLocaleString("en-US")} km, plausible`,
        discriminating: true,
      };
    }
    return {
      verdict: "disagree",
      note: `odometer up ${delta.toLocaleString("en-US")} km, too far`,
      discriminating: true,
    };
  },
};

/**
 * Price. Weak on purpose: a repost usually exists *because* the price changed,
 * so a delta is not evidence against. Only an implausible gap counts against.
 */
const price: Feature = {
  name: "price",
  weight: 3,
  evaluate: ({ a, b }) => {
    if (a.priceEur === null || b.priceEur === null) return unknown("price missing");
    if (a.priceEur === b.priceEur) {
      return { verdict: "agree", note: `identical asking price, EUR ${a.priceEur}`, discriminating: true };
    }
    const ratio = Math.abs(a.priceEur - b.priceEur) / Math.max(a.priceEur, b.priceEur);
    if (ratio <= 0.15) return { verdict: "unknown", note: `price differs ${Math.round(ratio * 100)}%, expected for a relist` };
    return { verdict: "disagree", note: `price differs ${Math.round(ratio * 100)}%` };
  },
};

/** Body colour. Cheap and reliably extracted on both sites; a mismatch is near-decisive. */
const color: Feature = {
  name: "color",
  weight: 5,
  evaluate: ({ a, b }) => {
    const same = sameText(a.color, b.color);
    if (same === null) return unknown("colour missing");
    return same
      ? { verdict: "agree", note: `both ${a.color}`, discriminating: false }
      : { verdict: "disagree", note: `${a.color} vs ${b.color}` };
  },
};

/** Cheap categorical agreement: body style, fuel, transmission, doors. Individually weak. */
const spec: Feature = {
  name: "spec",
  weight: 3,
  evaluate: ({ a, b }) => {
    const checks: Array<[string, boolean | null]> = [
      ["body", sameText(a.body, b.body)],
      ["fuel", sameText(a.fuel, b.fuel)],
      ["transmission", sameText(a.transmission, b.transmission)],
      ["doors", a.doors === null || b.doors === null ? null : a.doors === b.doors],
    ];
    const known = checks.filter(([, value]) => value !== null);
    if (known.length === 0) return unknown("no comparable spec fields");
    const disagreeing = known.filter(([, value]) => value === false).map(([name]) => name);
    if (disagreeing.length === 0) {
      return { verdict: "agree", strength: known.length / checks.length, note: `${known.length} spec fields agree` };
    }
    return { verdict: "disagree", strength: disagreeing.length / known.length, note: `differs on ${disagreeing.join(", ")}` };
  },
};

/**
 * Upholstery. Small, but it is one of the few fields that separates otherwise
 * identical stock — leather vs cloth on the same trim level is a different car.
 */
const upholstery: Feature = {
  name: "upholstery",
  weight: 3,
  evaluate: ({ a, b }) => {
    const same = sameText(a.upholstery, b.upholstery);
    if (same === null) return unknown("upholstery missing");
    return same
      ? { verdict: "agree", note: `both ${a.upholstery}` }
      : { verdict: "disagree", note: `${a.upholstery} vs ${b.upholstery}`, discriminating: true };
  },
};

/**
 * Seller. Not a similarity feature, and deliberately never scores `agree`.
 *
 * Two ads from the same dealer for cars of the same variant is the D5 false
 * positive, not evidence of a match. A genuine relist by the same dealer is
 * common too, so a shared seller cannot count against the pair either — it is
 * reported as context and used by `score.ts` to raise the bar.
 *
 * A *different* seller is mildly confirming for a cross-site pair: the same car
 * appearing under two dealer names usually means one aggregator republished it.
 */
const seller: Feature = {
  name: "seller",
  weight: 2,
  evaluate: ({ a, b }) => {
    const ka = sellerKey(a.sellerName);
    const kb = sellerKey(b.sellerName);
    if (ka === null || kb === null) return unknown("seller missing");
    if (ka === kb) {
      return { verdict: "unknown", note: `same seller (${a.sellerName}) — see same-seller rule` };
    }
    return { verdict: "agree", strength: 0.5, note: `listed by two sellers`, discriminating: false };
  },
};

export const FEATURES: readonly Feature[] = [
  makeModel, trim, firstRegistration, power, mileage, price, color, spec, upholstery, seller,
];

export function buildContext(a: Listing, b: Listing): FeatureContext {
  const gap = daysBetween(a.capturedAt, b.capturedAt);
  const aIsEarlier = gap === null ? true : gap >= 0;
  return {
    a, b,
    earlier: aIsEarlier ? a : b,
    later: aIsEarlier ? b : a,
    elapsedDays: gap === null ? null : Math.abs(gap),
  };
}

export function toEvidence(feature: Feature, reading: FeatureReading): Evidence {
  const strength = reading.strength ?? 1;
  const magnitude = feature.weight * Math.max(0, Math.min(1, strength));
  const contribution =
    reading.verdict === "agree" ? magnitude : reading.verdict === "disagree" ? -magnitude : 0;
  return {
    feature: feature.name,
    verdict: reading.verdict,
    contribution,
    available: reading.verdict === "unknown" ? 0 : feature.weight,
    // A disagreement always matters. An agreement only earns a place on the
    // confirmation card when the feature said so — "both grey" is not evidence.
    discriminating: reading.discriminating ?? reading.verdict === "disagree",
    note: reading.note,
  };
}
