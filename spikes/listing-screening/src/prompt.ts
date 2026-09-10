/**
 * Prompt construction.
 *
 * One criterion per call, deliberately. Batching all three into one response
 * saves tokens but confounds the measurement: a model that gets warranty wrong
 * because it was still reasoning about upholstery tells us nothing about
 * warranty. On-device inference is free, so there is nothing to save.
 */
import { CRITERIA_BY_ID } from "./criteria.ts";
import { ANSWER_JSON_SCHEMA } from "./schema.ts";
import type { Case, CriterionId, PromptMode } from "./types.ts";

/**
 * The instruction shared by every call. The abstention rule is stated first and
 * last: D10 makes `unknown` the whole point, and a 3B model weights the ends of
 * an instruction block far more than the middle.
 */
const SYSTEM = `You screen Dutch second-hand car listings against one criterion at a time.

Rules:
1. Answer ONLY from the listing text given to you. Never use world knowledge about the make, model or trim level.
2. If the listing does not state the answer, the answer is "unknown". Do not infer, do not estimate, do not answer "probably".
3. A contradiction inside the listing is also "unknown".
4. Reply with a single JSON object and nothing else.

Output schema:
${JSON.stringify(ANSWER_JSON_SCHEMA, null, 2)}

"evidence" must be a verbatim quote from the listing, and must be null when the value is "unknown".
When in doubt, answer "unknown". An honest "unknown" is more useful than a confident guess.`;

/**
 * Only show structured fields that can answer the active criterion. Identity,
 * mileage and price invite inference; unrelated facts bury the evidence in a
 * small model's context. Warranty inclusion has no reliable structured field.
 */
const STRUCTURED_KEYS_BY_CRITERION: Readonly<Record<CriterionId, readonly string[]>> = {
  warranty_included: [],
  reversing_camera: ["equipment"],
  leather_upholstery: ["upholstery"],
};

export interface Prompt {
  readonly id: string;
  readonly criterion: CriterionId;
  readonly mode: PromptMode;
  readonly system: string;
  /** Listing content only. Guided generation uses this so the question cannot become evidence. */
  readonly evidence: string;
  readonly user: string;
}

/** Input spans that are valid answer evidence. The question is deliberately excluded. */
export function buildEvidenceSource(item: Case, criterion: CriterionId, mode: PromptMode): string {
  const sections: string[] = [];

  if (mode === "full") {
    const facts = STRUCTURED_KEYS_BY_CRITERION[criterion].flatMap((key) => {
      const value = item.structured[key];
      if (value === undefined || value === null || value === "") return [];
      if (Array.isArray(value)) return value.length === 0 ? [] : [`${key}: ${value.join(", ")}`];
      return [`${key}: ${String(value)}`];
    });
    if (facts.length > 0) sections.push(`GESTRUCTUREERDE GEGEVENS VAN DE PAGINA\n${facts.join("\n")}`);
  }

  sections.push(`OMSCHRIJVING VAN DE VERKOPER\n${item.description || "(geen omschrijving)"}`);
  return sections.join("\n\n---\n\n");
}

export function buildPrompt(item: Case, criterion: CriterionId, mode: PromptMode): Prompt {
  const definition = CRITERIA_BY_ID.get(criterion);
  if (definition === undefined) throw new Error(`unknown criterion: ${criterion}`);

  const evidence = buildEvidenceSource(item, criterion, mode);
  const sections = [evidence];
  sections.push(`VRAAG (criterion id: ${criterion})\n${definition.question}`);

  return { id: item.id, criterion, mode, system: SYSTEM, evidence, user: sections.join("\n\n---\n\n") };
}

/**
 * Every prompt for a run. `text_only` is the mode that tests D10: with the
 * structured block withheld, the correct answer for most reversing-camera and
 * upholstery cases becomes `unknown`, and a model that keeps answering `yes`
 * is inferring from make and model rather than reading.
 */
export function buildAll(cases: readonly Case[], modes: readonly PromptMode[]): Prompt[] {
  const prompts: Prompt[] = [];
  for (const mode of modes) {
    for (const item of cases) {
      for (const criterion of CRITERIA_BY_ID.keys()) {
        prompts.push(buildPrompt(item, criterion, mode));
      }
    }
  }
  return prompts;
}
