/**
 * Synthetic repost stress test.
 *
 * The corpus contains no repost. Its two `same_car` pairs are same-day
 * cross-site captures that agree on plate, odometer *and* asking price — the
 * easiest positive that exists. Measuring against them says almost nothing
 * about the case the product is for: the same car, relisted weeks later, by a
 * different dealer, at a different price.
 *
 * So this file manufactures that case. Each real listing is degraded along one
 * axis at a time and matched against its own original with the plate withheld.
 * The result is not evidence that the matcher works — synthetic positives can
 * only ever confirm the generator's own assumptions. It is a sensitivity
 * analysis: it says which feature the score is leaning on, and how far each
 * axis can move before recall collapses.
 *
 * Read it as "the matcher survives X" — never as a measured recall rate.
 *
 * Usage: node --experimental-strip-types src/stress.ts
 */
import { loadListings } from "./corpus.ts";
import { DEFAULT_THRESHOLDS, match } from "./score.ts";
import type { Listing } from "./types.ts";

interface Scenario {
  readonly name: string;
  readonly note: string;
  readonly degrade: (listing: Listing) => Listing;
}

const addDays = (iso: string | null, days: number): string | null => {
  if (iso === null) return null;
  const parsed = Date.parse(iso);
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed + days * 86_400_000).toISOString();
};

/** Drop the trailing share of trim tokens, as a different dealer rewriting the spec line would. */
const rewordTrim = (trim: string | null, keep: number): string | null => {
  if (trim === null) return null;
  const words = trim.split(/\s+/).filter((word) => word !== "");
  return words.slice(0, Math.max(1, Math.round(words.length * keep))).join(" ");
};

/**
 * A relist: later capture, odometer moved forward at a forecourt-plausible rate,
 * price cut, new dealer, reworded spec line. `days` drives all of it.
 */
function relist(days: number, priceCut: number, keepTrim: number): (listing: Listing) => Listing {
  return (listing) => ({
    ...listing,
    id: `${listing.id}#relist+${days}d`,
    listingId: `${listing.listingId ?? "x"}-relisted`,
    capturedAt: addDays(listing.capturedAt, days),
    // ~1 100 km/month is typical for a car sitting on a forecourt being moved
    // between branches and test-driven.
    mileageKm: listing.mileageKm === null ? null : listing.mileageKm + Math.round(days * 36),
    priceEur: listing.priceEur === null ? null : Math.round(listing.priceEur * (1 - priceCut)),
    sellerName: "Andere Autohandel B.V.",
    sellerCity: "ELDERS",
    trim: rewordTrim(listing.trim, keepTrim),
  });
}

/** The AutoTrack extraction profile: JSON-LD only, so several fields simply are not there. */
const thinProfile = (listing: Listing): Listing => ({
  ...listing,
  id: `${listing.id}#thin`,
  listingId: `${listing.listingId ?? "x"}-thin`,
  site: "othersite.nl",
  firstRegistration: null,
  powerHp: null,
  upholstery: null,
  sellerName: null,
  sellerCity: null,
  variant: null,
});

const SCENARIOS: readonly Scenario[] = [
  {
    name: "same day, new ad",
    note: "identical data, new listing id — the floor",
    degrade: (listing) => ({ ...listing, id: `${listing.id}#dup`, listingId: `${listing.listingId ?? "x"}-dup` }),
  },
  { name: "relist +30d", note: "+1 080 km, -3% price, new dealer, trim 80% kept", degrade: relist(30, 0.03, 0.8) },
  { name: "relist +90d", note: "+3 240 km, -7% price, new dealer, trim 70% kept", degrade: relist(90, 0.07, 0.7) },
  { name: "relist +180d", note: "+6 480 km, -12% price, new dealer, trim 50% kept", degrade: relist(180, 0.12, 0.5) },
  { name: "relist +365d", note: "+13 140 km, -20% price, new dealer, trim 40% kept", degrade: relist(365, 0.2, 0.4) },
  { name: "thin extraction", note: "same car via a JSON-LD-only site", degrade: thinProfile },
  {
    name: "thin + relist +90d",
    note: "the realistic worst case: thin site, three months later",
    degrade: (listing) => thinProfile(relist(90, 0.07, 0.7)(listing)),
  },
  {
    name: "odometer rolled back",
    note: "must NOT match — this is a warning, not a car",
    degrade: (listing) => ({
      ...listing,
      id: `${listing.id}#rolled`,
      listingId: `${listing.listingId ?? "x"}-rolled`,
      capturedAt: addDays(listing.capturedAt, 90),
      mileageKm: listing.mileageKm === null ? null : listing.mileageKm - 30_000,
    }),
  },
];

function main(): void {
  // Only listings with an odometer and a price can be degraded meaningfully.
  const listings = loadListings().filter(
    (listing) => listing.mileageKm !== null && listing.priceEur !== null,
  );

  console.log(`synthetic reposts derived from ${listings.length} real listings`);
  console.log(`plate withheld, vetoes on, probable threshold ${DEFAULT_THRESHOLDS.probable}\n`);
  console.log(
    `${"scenario".padEnd(22)} ${"recalled".padStart(8)}  ${"median".padStart(6)}  ${"worst".padStart(6)}  note`,
  );
  console.log("-".repeat(100));

  for (const scenario of SCENARIOS) {
    const results = listings.map((listing) =>
      match(listing, scenario.degrade(listing), { ignoreHardKeys: true }),
    );
    const recalled = results.filter(
      (result) => result.band === "exact" || result.band === "probable",
    ).length;
    const scores = results
      .map((result) => result.score)
      .filter((value): value is number => value !== null)
      .sort((x, y) => x - y);
    const median = scores.length === 0 ? null : scores[Math.floor(scores.length / 2)] ?? null;
    const worst = scores.length === 0 ? null : scores[0] ?? null;
    console.log(
      `${scenario.name.padEnd(22)} ${`${recalled}/${listings.length}`.padStart(8)}  ${(median?.toFixed(2) ?? "—").padStart(6)}  ${(worst?.toFixed(2) ?? "—").padStart(6)}  ${scenario.note}`,
    );
  }

  console.log(
    "\nThe last row is a negative control: anything above 0 recalled there is a bug,\nnot a feature — a backwards odometer means a different car or a tampered one.",
  );
}

main();
