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

/** The structured facts worth showing in `full` mode. Deliberately narrow: dumping every field buries the question. */
const STRUCTURED_KEYS = [
  "make", "model", "trim", "firstRegistration", "mileageKm", "priceEur",
  "upholstery", "warranty", "warrantyExists", "equipment",
] as const;

export interface Prompt {
  readonly id: string;
  readonly criterion: CriterionId;
  readonly mode: PromptMode;
  readonly system: string;
  readonly user: string;
}

export function buildPrompt(item: Case, criterion: CriterionId, mode: PromptMode): Prompt {
  const definition = CRITERIA_BY_ID.get(criterion);
  if (definition === undefined) throw new Error(`unknown criterion: ${criterion}`);

  const sections: string[] = [];

  if (mode === "full") {
    const facts = STRUCTURED_KEYS.map((key) => {
      const value = item.structured[key];
      if (value === undefined || value === null) return `${key}: (niet vermeld)`;
      if (Array.isArray(value)) return `${key}: ${value.join(", ")}`;
      return `${key}: ${String(value)}`;
    });
    sections.push(`GESTRUCTUREERDE GEGEVENS VAN DE PAGINA\n${facts.join("\n")}`);
  }

  sections.push(`OMSCHRIJVING VAN DE VERKOPER\n${item.description || "(geen omschrijving)"}`);
  sections.push(`VRAAG (criterion id: ${criterion})\n${definition.question}`);

  return { id: item.id, criterion, mode, system: SYSTEM, user: sections.join("\n\n---\n\n") };
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
