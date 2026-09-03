/**
 * The measurement. Scores every pair in the corpus, compares against
 * `pairs.csv`, and prints recall and false-positive rate.
 *
 * Three scenarios, and the third is the one that carries information:
 *
 *   1. hard keys on          — what ships. Both known `same_car` pairs share a
 *                              plate, so this run is close to a tautology.
 *   2. plate/listing id off  — models a site that publishes no plate, and the
 *                              pre-extraction provisional match in D3.
 *   3. vetoes off too        — the weighted score alone, with nothing to hide
 *                              behind. This is the D7 question.
 *
 * The headline percentages are the least useful output here: with 2 positives
 * they saturate at 100% under almost any settings. The margin between the worst
 * true positive and the best true negative is the number to read.
 *
 * Usage:
 *   npm run evaluate
 *   npm run evaluate -- --sweep      also sweep the thresholds
 *   npm run evaluate -- --pairs      dump every non-`different` verdict
 */
import { loadListings, loadPairs, pairKey, truthFor, type Relation } from "./corpus.ts";
import { DEFAULT_THRESHOLDS, match, type MatchOptions, type Thresholds } from "./score.ts";
import type { Band, Listing, MatchResult } from "./types.ts";

interface Scored {
  readonly a: Listing;
  readonly b: Listing;
  readonly truth: Relation;
  readonly result: MatchResult;
}

/** A band counts as "the matcher proposed a match" when it would reach the user. */
const proposes = (band: Band): boolean => band === "exact" || band === "probable";

function scoreAll(
  listings: readonly Listing[],
  truth: Map<string, Relation>,
  options: MatchOptions,
): Scored[] {
  const scored: Scored[] = [];
  for (let i = 0; i < listings.length; i += 1) {
    for (let j = i + 1; j < listings.length; j += 1) {
      const a = listings[i];
      const b = listings[j];
      if (a === undefined || b === undefined) continue;
      scored.push({
        a,
        b,
        truth: truth.get(pairKey(a.id, b.id)) ?? "different",
        result: match(a, b, options),
      });
    }
  }
  return scored;
}

interface Counts {
  readonly positives: number;
  readonly recalled: number;
  readonly missed: readonly Scored[];
  readonly falsePositives: readonly Scored[];
  readonly hardNegativesCaught: number;
  readonly hardNegatives: number;
  readonly retained: number;
}

function tally(scored: readonly Scored[]): Counts {
  const positives = scored.filter((pair) => pair.truth === "same_car");
  const hardNegatives = scored.filter((pair) => pair.truth === "same_variant_diff_car");
  return {
    positives: positives.length,
    recalled: positives.filter((pair) => proposes(pair.result.band)).length,
    missed: positives.filter((pair) => !proposes(pair.result.band)),
    falsePositives: scored.filter(
      (pair) => pair.truth !== "same_car" && proposes(pair.result.band),
    ),
    hardNegativesCaught: hardNegatives.filter((pair) => !proposes(pair.result.band)).length,
    hardNegatives: hardNegatives.length,
    retained: scored.filter((pair) => pair.result.band === "retained").length,
  };
}

const pct = (n: number, d: number): string =>
  d === 0 ? "n/a" : `${((n / d) * 100).toFixed(0)}%`;

const short = (listing: Listing): string => {
  const site = listing.site.split(".")[0] ?? listing.site;
  const tail = listing.id.replace(/^[a-z0-9]+_/, "").slice(0, 34);
  return `${site}:${tail}`;
};

/** What decided this pair — the distinction the headline numbers hide. */
function mechanism(result: MatchResult): string {
  if (result.hardKey !== null) return `hard key: ${result.hardKey}`;
  if (result.vetoes.length > 0) return `veto: ${result.vetoes.map((v) => v.feature).join(", ")}`;
  return `score ${result.score?.toFixed(2) ?? "n/a"}`;
}

/** How each true negative got rejected. The headline numbers hide this, and it is the finding. */
function mechanismBreakdown(scored: readonly Scored[]): void {
  const tallies = new Map<string, number>();
  for (const pair of scored) {
    if (pair.truth === "same_car" || proposes(pair.result.band)) continue;
    const key =
      pair.result.vetoes.length > 0
        ? `veto: ${pair.result.vetoes.map((v) => v.feature).join("+")}`
        : `below threshold (${pair.result.band})`;
    tallies.set(key, (tallies.get(key) ?? 0) + 1);
  }
  console.log("\n  negatives rejected by:");
  for (const [key, count] of [...tallies].sort((x, y) => y[1] - x[1])) {
    console.log(`    ${String(count).padStart(4)}  ${key}`);
  }
}

function report(label: string, scored: readonly Scored[]): Counts {
  const counts = tally(scored);
  const total = scored.length;
  console.log(`\n${"=".repeat(78)}\n${label}\n${"=".repeat(78)}`);
  console.log(`pairs compared            ${total}`);
  console.log(
    `same_car recalled         ${counts.recalled}/${counts.positives}  (${pct(counts.recalled, counts.positives)})`,
  );
  console.log(
    `same_variant rejected     ${counts.hardNegativesCaught}/${counts.hardNegatives}  (${pct(counts.hardNegativesCaught, counts.hardNegatives)})`,
  );
  console.log(
    `false positives           ${counts.falsePositives.length}/${total - counts.positives}  (${pct(counts.falsePositives.length, total - counts.positives)})`,
  );
  console.log(`retained for later link   ${counts.retained}`);

  const scoreOf = (pair: Scored): number | null => pair.result.score;
  const positiveScores = scored
    .filter((p) => p.truth === "same_car")
    .map(scoreOf)
    .filter((value): value is number => value !== null);
  const negativeScores = scored
    .filter((p) => p.truth !== "same_car")
    .map(scoreOf)
    .filter((value): value is number => value !== null);
  if (positiveScores.length > 0 && negativeScores.length > 0) {
    const worstPositive = Math.min(...positiveScores);
    const bestNegative = Math.max(...negativeScores);
    console.log(
      `score margin              worst positive ${worstPositive.toFixed(2)} - best negative ${bestNegative.toFixed(2)} = ${(worstPositive - bestNegative).toFixed(2)}`,
    );
  }

  if (counts.positives > 0) {
    console.log("\n  same_car pairs:");
    for (const pair of scored.filter((p) => p.truth === "same_car")) {
      const mark = proposes(pair.result.band) ? "PASS" : "MISS";
      console.log(`    ${mark}  ${pair.result.band.padEnd(9)} ${mechanism(pair.result).padEnd(22)} ${short(pair.a)} <-> ${short(pair.b)}`);
      for (const item of pair.result.discriminators.slice(0, 3)) {
        console.log(`            - ${item.note}`);
      }
    }
  }

  mechanismBreakdown(scored);

  if (counts.falsePositives.length > 0) {
    console.log("\n  false positives:");
    for (const pair of counts.falsePositives) {
      console.log(`    ${pair.result.band.padEnd(9)} ${mechanism(pair.result).padEnd(22)} ${short(pair.a)} <-> ${short(pair.b)}`);
      for (const item of pair.result.discriminators.slice(0, 3)) {
        console.log(`            - ${item.note}`);
      }
    }
  }

  return counts;
}

function sweep(listings: readonly Listing[], truth: Map<string, Relation>): void {
  console.log(`\n${"=".repeat(78)}\nThreshold sweep on the bare score (no hard keys, no vetoes)\n${"=".repeat(78)}`);
  console.log("  probable   recall    false pos   retained");
  for (let t = 0.4; t <= 0.9001; t += 0.05) {
    const thresholds: Thresholds = { ...DEFAULT_THRESHOLDS, probable: t };
    const scored = scoreAll(listings, truth, {
      thresholds,
      ignoreHardKeys: true,
      ignoreVetoes: true,
    });
    const counts = tally(scored);
    console.log(
      `  ${t.toFixed(2).padStart(8)}   ${`${counts.recalled}/${counts.positives}`.padStart(6)}    ${String(counts.falsePositives.length).padStart(9)}   ${String(counts.retained).padStart(8)}`,
    );
  }
}

function dumpPairs(scored: readonly Scored[]): void {
  console.log(`\n${"=".repeat(78)}\nEvery pair the matcher did not reject, hard keys OFF\n${"=".repeat(78)}`);
  const interesting = scored
    .filter((pair) => pair.result.band !== "different")
    .sort((x, y) => (y.result.score ?? 1) - (x.result.score ?? 1));
  for (const pair of interesting) {
    console.log(
      `${pair.result.band.padEnd(9)} ${(pair.result.score?.toFixed(2) ?? "hard").padStart(5)}  ${pair.truth.padEnd(21)} ${short(pair.a)} <-> ${short(pair.b)}`,
    );
  }
}

function main(): void {
  const args = new Set(process.argv.slice(2));
  const listings = loadListings();
  const truth = truthFor(loadPairs());

  console.log(`listings ${listings.length}   labelled pairs ${truth.size}`);
  console.log(
    `thresholds  probable ${DEFAULT_THRESHOLDS.probable}  retained ${DEFAULT_THRESHOLDS.retained}  same-seller penalty +${DEFAULT_THRESHOLDS.sameSellerPenalty}`,
  );

  report("1. Hard keys ON — what ships", scoreAll(listings, truth, {}));

  const fuzzy = scoreAll(listings, truth, { ignoreHardKeys: true });
  report("2. Plate and listing id withheld — the D7 question", fuzzy);

  report(
    "3. Ablation: no hard keys, no vetoes — the weighted score alone",
    scoreAll(listings, truth, { ignoreHardKeys: true, ignoreVetoes: true }),
  );

  if (args.has("--sweep")) sweep(listings, truth);
  if (args.has("--pairs")) dumpPairs(fuzzy);
}

main();
