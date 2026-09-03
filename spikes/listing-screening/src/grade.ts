/**
 * Grading.
 *
 * The headline "accuracy" number is the least interesting thing here, because
 * the three ways of being wrong have wildly different costs (D10):
 *
 *   hallucination   truth is `unknown`, model said yes/no.  The trust-destroying
 *                   failure. "Reversing camera: probably yes" is the exact thing
 *                   D10 forbids, and it is worse than any other error.
 *   wrong direction truth is yes, model said no (or vice versa). A real mistake,
 *                   but an auditable one — the evidence quote shows why.
 *   over-abstention truth is yes/no, model said unknown. Costs the user a manual
 *                   read. Cheap, and the safe direction to fail in.
 *
 * A model that scores 70% with zero hallucinations is more useful than one that
 * scores 85% with six, so they are never summed into one figure.
 */
import type { Case, CriterionId, CriterionValue, Label } from "./types.ts";

export type ErrorKind = "correct" | "hallucination" | "wrong_direction" | "over_abstention";

export function classify(expected: CriterionValue, actual: CriterionValue): ErrorKind {
  if (expected === actual) return "correct";
  if (expected === "unknown") return "hallucination";
  if (actual === "unknown") return "over_abstention";
  return "wrong_direction";
}

export interface Judgement {
  readonly id: string;
  readonly criterion: CriterionId;
  readonly expected: CriterionValue;
  /** null when the response never parsed — a schema violation, not a wrong answer. */
  readonly actual: CriterionValue | null;
  readonly kind: ErrorKind | null;
  readonly violation: string | null;
  readonly evidence: string | null;
  readonly provenance: Label["provenance"];
  /** True when the cited evidence does not appear in what the model was shown. */
  readonly fabricatedEvidence: boolean;
}

export interface Report {
  readonly label: string;
  readonly total: number;
  readonly violations: number;
  readonly correct: number;
  readonly hallucinations: number;
  readonly wrongDirection: number;
  readonly overAbstention: number;
  readonly fabricatedEvidence: number;
  readonly judgements: readonly Judgement[];
}

/**
 * A quoted span must actually occur in the input. A model that invents a
 * plausible Dutch sentence to justify an answer is failing in a way no
 * value-level metric catches, and on a 3B model it is a real risk.
 */
export function evidenceIsFabricated(evidence: string | null, shown: string): boolean {
  if (evidence === null) return false;
  const needle = normalize(evidence);
  if (needle.length < 8) return false; // too short to judge
  return !normalize(shown).includes(needle);
}

const normalize = (value: string): string =>
  value.toLowerCase().replace(/\s+/g, " ").replace(/[^\p{L}\p{N} ]/gu, "").trim();

export function summarize(label: string, judgements: readonly Judgement[]): Report {
  const count = (kind: ErrorKind): number =>
    judgements.filter((judgement) => judgement.kind === kind).length;
  return {
    label,
    total: judgements.length,
    violations: judgements.filter((judgement) => judgement.violation !== null).length,
    correct: count("correct"),
    hallucinations: count("hallucination"),
    wrongDirection: count("wrong_direction"),
    overAbstention: count("over_abstention"),
    fabricatedEvidence: judgements.filter((judgement) => judgement.fabricatedEvidence).length,
    judgements,
  };
}

/** Grade a deterministic answerer — the baselines, and anything else without a model. */
export function gradeAnswerer(
  label: string,
  cases: readonly Case[],
  labels: ReadonlyMap<string, Label>,
  criteria: readonly CriterionId[],
  answer: (item: Case, criterion: CriterionId) => CriterionValue,
): Report {
  const judgements: Judgement[] = [];
  for (const item of cases) {
    for (const criterion of criteria) {
      const expectation = labels.get(`${item.id}::${criterion}`);
      if (expectation === undefined) continue;
      const actual = answer(item, criterion);
      judgements.push({
        id: item.id,
        criterion,
        expected: expectation.expected,
        actual,
        kind: classify(expectation.expected, actual),
        violation: null,
        evidence: null,
        provenance: expectation.provenance,
        fabricatedEvidence: false,
      });
    }
  }
  return summarize(label, judgements);
}

const pct = (n: number, d: number): string => (d === 0 ? "  n/a" : `${((n / d) * 100).toFixed(0)}%`.padStart(4));

export function printReport(report: Report): void {
  const graded = report.total - report.violations;
  console.log(`\n${report.label}`);
  console.log(`  graded            ${graded}/${report.total}${report.violations > 0 ? `  (${report.violations} schema violations)` : ""}`);
  console.log(`  correct           ${String(report.correct).padStart(3)}   ${pct(report.correct, graded)}`);
  console.log(`  hallucination     ${String(report.hallucinations).padStart(3)}   ${pct(report.hallucinations, graded)}   <- the D10 failure`);
  console.log(`  wrong direction   ${String(report.wrongDirection).padStart(3)}   ${pct(report.wrongDirection, graded)}`);
  console.log(`  over-abstention   ${String(report.overAbstention).padStart(3)}   ${pct(report.overAbstention, graded)}   (safe)`);
  if (report.fabricatedEvidence > 0) {
    console.log(`  fabricated quotes ${String(report.fabricatedEvidence).padStart(3)}   ${pct(report.fabricatedEvidence, graded)}   <- cited text that was not shown`);
  }
}

/** Per-criterion split of one report. */
export function printByCriterion(report: Report, criteria: readonly CriterionId[]): void {
  console.log(`  ${"criterion".padEnd(20)} ${"correct".padStart(8)} ${"halluc".padStart(7)} ${"wrong".padStart(6)} ${"abstain".padStart(8)}`);
  for (const criterion of criteria) {
    const subset = report.judgements.filter((judgement) => judgement.criterion === criterion);
    if (subset.length === 0) continue;
    const n = (kind: ErrorKind): string =>
      String(subset.filter((judgement) => judgement.kind === kind).length).padStart(6);
    console.log(
      `  ${criterion.padEnd(20)} ${n("correct")}/${String(subset.length).padStart(2)}${n("hallucination")} ${n("wrong_direction").trim().padStart(6)} ${n("over_abstention").trim().padStart(8)}`,
    );
  }
}
