/**
 * CLI.
 *
 *   npm run baseline                 grade the two no-model options
 *   npm run emit                     write prompts.jsonl for a runner
 *   npm run grade -- responses.jsonl grade recorded model output
 *   npm run mock                     fake responses from the keyword baseline,
 *                                    so the grading path can be exercised and
 *                                    reviewed without a Mac in the room
 *
 * The model call itself is not here: Apple's Foundation Models framework is
 * Swift-only and macOS/iOS-only, so the runner lives on the Mac and hands back
 * JSONL. See README for the ~40 lines of Swift that does it.
 */
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { baselineAnswer, structuredAnswer } from "./baseline.ts";
import { loadCases, loadLabels, loadResponses, labelIndex, ROOT } from "./corpus.ts";
import { CRITERIA } from "./criteria.ts";
import {
  classify, evidenceIsFabricated, gradeAnswerer, printByCriterion, printReport, summarize,
  type Judgement,
} from "./grade.ts";
import { buildAll, buildPrompt } from "./prompt.ts";
import { parseAnswer } from "./schema.ts";
import type { CriterionId, PromptMode } from "./types.ts";

const ALL_CRITERIA = CRITERIA.map((criterion) => criterion.id);
/** Only warranty has a label that holds when the structured block is withheld. */
const TEXT_ONLY_GRADABLE: readonly CriterionId[] = ["warranty_included"];

function baseline(): void {
  const cases = loadCases();
  const labels = labelIndex(loadLabels());

  console.log(`${cases.length} listings, ${ALL_CRITERIA.length} criteria, ${cases.length * ALL_CRITERIA.length} judgements`);
  console.log("\nThe floor the on-device model has to beat. If it does not beat both of");
  console.log("these, D16 is answered without a model.");

  const keyword = gradeAnswerer(
    "keyword baseline (regex over the description)", cases, labels, ALL_CRITERIA, baselineAnswer,
  );
  printReport(keyword);
  printByCriterion(keyword, ALL_CRITERIA);

  const structured = gradeAnswerer(
    "structured baseline (page fields only, no text)", cases, labels, ALL_CRITERIA, structuredAnswer,
  );
  printReport(structured);
  printByCriterion(structured, ALL_CRITERIA);

  console.log("\nDisagreements on the criterion that matters:");
  for (const judgement of structured.judgements) {
    if (judgement.criterion !== "warranty_included" || judgement.kind === "correct") continue;
    const label = labels.get(`${judgement.id}::${judgement.criterion}`);
    console.log(
      `  ${judgement.kind?.padEnd(16)} expected ${judgement.expected.padEnd(7)} got ${String(judgement.actual).padEnd(7)} ${judgement.id.slice(12, 52)}`,
    );
    if (label !== undefined) console.log(`      ${label.note}`);
  }
}

function emit(modes: readonly PromptMode[]): void {
  const cases = loadCases();
  const prompts = buildAll(cases, modes);
  const out = resolve(ROOT, "fixtures/prompts.jsonl");
  writeFileSync(out, prompts.map((prompt) => JSON.stringify(prompt)).join("\n") + "\n", "utf8");
  const chars = prompts.reduce((sum, prompt) => sum + prompt.system.length + prompt.user.length, 0);
  console.log(`wrote ${prompts.length} prompts -> ${out}`);
  console.log(`modes: ${modes.join(", ")}`);
  console.log(`~${Math.round(chars / prompts.length)} chars per prompt, ~${Math.round(chars / 3.6 / 1000)}k tokens total`);
}

/**
 * Emit responses.jsonl as if a model had produced the keyword baseline's answers.
 * Not a model and not a result — it exists so the grader, the schema validator
 * and the report can be run and reviewed on any machine.
 */
function mock(): void {
  const cases = loadCases();
  const out = resolve(ROOT, "fixtures/responses-mock.jsonl");
  const lines: string[] = [];
  for (const mode of ["full", "text_only"] as PromptMode[]) {
    for (const item of cases) {
      for (const criterion of ALL_CRITERIA) {
        const value = baselineAnswer(item, criterion);
        // Quote a real span so the fabricated-evidence check has something true
        // to pass on; `unknown` must carry no evidence at all.
        const evidence =
          value === "unknown" ? null : (firstSentenceMentioning(item.description, criterion) ?? item.description.slice(0, 60));
        lines.push(
          JSON.stringify({
            id: item.id,
            criterion,
            mode,
            raw: JSON.stringify({ criterion, value, evidence }),
            meta: { runner: "mock-keyword-baseline" },
          }),
        );
      }
    }
  }
  writeFileSync(out, lines.join("\n") + "\n", "utf8");
  console.log(`wrote ${lines.length} mock responses -> ${out}`);
  console.log("this is the keyword baseline wearing a model's clothes, not a result");
}

const CRITERION_WORD: Readonly<Record<CriterionId, RegExp>> = {
  warranty_included: /garantie/i,
  reversing_camera: /camera/i,
  leather_upholstery: /leder|leer|stof/i,
};

function firstSentenceMentioning(text: string, criterion: CriterionId): string | null {
  const needle = CRITERION_WORD[criterion];
  for (const line of text.split("\n")) {
    if (needle.test(line)) return line.slice(0, 160);
  }
  return null;
}

function grade(path: string): void {
  const cases = loadCases();
  const caseById = new Map(cases.map((item) => [item.id, item]));
  const labels = labelIndex(loadLabels());
  const responses = loadResponses(path);

  const byMode = new Map<PromptMode, Judgement[]>();
  for (const response of responses) {
    const item = caseById.get(response.id);
    if (item === undefined) {
      console.error(`skipping unknown listing id: ${response.id}`);
      continue;
    }
    const gradable = response.mode === "text_only" ? TEXT_ONLY_GRADABLE : ALL_CRITERIA;
    if (!gradable.includes(response.criterion)) continue;

    const expectation = labels.get(`${response.id}::${response.criterion}`);
    if (expectation === undefined) continue;

    const parsed = parseAnswer(response.raw, response.criterion);
    const shown = buildPrompt(item, response.criterion, response.mode).user;
    const judgement: Judgement = parsed.ok
      ? {
          id: response.id,
          criterion: response.criterion,
          expected: expectation.expected,
          actual: parsed.answer.value,
          kind: classify(expectation.expected, parsed.answer.value),
          violation: null,
          evidence: parsed.answer.evidence,
          provenance: expectation.provenance,
          fabricatedEvidence: evidenceIsFabricated(parsed.answer.evidence, shown),
        }
      : {
          id: response.id,
          criterion: response.criterion,
          expected: expectation.expected,
          actual: null,
          kind: null,
          violation: parsed.violation,
          evidence: null,
          provenance: expectation.provenance,
          fabricatedEvidence: false,
        };
    const bucket = byMode.get(response.mode) ?? [];
    bucket.push(judgement);
    byMode.set(response.mode, bucket);
  }

  if (byMode.size === 0) {
    console.error("no gradable responses found");
    process.exitCode = 1;
    return;
  }

  for (const [mode, judgements] of byMode) {
    const report = summarize(`model, ${mode} mode`, judgements);
    printReport(report);
    printByCriterion(report, ALL_CRITERIA);

    const notable = judgements.filter(
      (judgement) =>
        judgement.violation !== null || judgement.fabricatedEvidence ||
        judgement.kind === "hallucination" || judgement.kind === "wrong_direction",
    );
    if (notable.length > 0) {
      console.log("\n  every failure worth reading:");
      for (const judgement of notable) {
        const what = judgement.violation ?? judgement.kind ?? "?";
        console.log(`    ${what.padEnd(16)} ${judgement.criterion.padEnd(20)} expected ${judgement.expected.padEnd(7)} got ${String(judgement.actual)}`);
        console.log(`      ${judgement.id.slice(12, 60)}`);
        if (judgement.evidence !== null) {
          console.log(`      cited${judgement.fabricatedEvidence ? " (NOT IN INPUT)" : ""}: ${judgement.evidence.slice(0, 110)}`);
        }
      }
    }
  }

  // The disputed labels are the ones where the prose and the recorded verdict
  // conflict. If the model tracks the prose, that is evidence for the prose.
  const disputed = [...byMode.values()].flat().filter((judgement) => judgement.provenance === "disputed");
  if (disputed.length > 0) {
    console.log("\n  on the disputed labels (prose vs. recorded verdict):");
    for (const judgement of disputed) {
      console.log(`    ${judgement.id.slice(12, 52).padEnd(42)} expected ${judgement.expected.padEnd(7)} got ${String(judgement.actual)}`);
    }
  }
}

function main(): void {
  const [command = "baseline", ...rest] = process.argv.slice(2);
  switch (command) {
    case "baseline":
      baseline();
      return;
    case "emit": {
      const modes = rest.length > 0 ? (rest as PromptMode[]) : (["full", "text_only"] as PromptMode[]);
      emit(modes);
      return;
    }
    case "mock":
      mock();
      return;
    case "grade": {
      const path = rest[0];
      if (path === undefined) {
        console.error("usage: grade <responses.jsonl>");
        process.exitCode = 1;
        return;
      }
      grade(resolve(path));
      return;
    }
    default:
      console.error(`unknown command: ${command}`);
      process.exitCode = 1;
  }
}

main();
