/**
 * The strict output contract from D9, and its validator.
 *
 * A small model's failures split into two kinds that must never be averaged
 * together: it answered the wrong thing, or it did not answer in the required
 * shape at all. The second is a runner/prompt problem and is often fixable by
 * constrained decoding; the first is a capability problem and is not. So a
 * malformed response is recorded as a `SchemaViolation`, never silently coerced
 * into a value.
 */
import type { CriterionId, CriterionValue, ScreeningAnswer } from "./types.ts";
import { CRITERIA_BY_ID } from "./criteria.ts";

const VALUES = new Set<string>(["yes", "no", "unknown"]);

/** JSON Schema for runners that support constrained decoding. Keep in step with `parseAnswer`. */
export const ANSWER_JSON_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["criterion", "value", "evidence"],
  properties: {
    criterion: { type: "string" },
    value: { type: "string", enum: ["yes", "no", "unknown"] },
    evidence: {
      type: ["string", "null"],
      description:
        "Verbatim span from the input supporting the answer. Null when value is 'unknown'.",
    },
  },
} as const;

export type ParseOutcome =
  | { readonly ok: true; readonly answer: ScreeningAnswer }
  | { readonly ok: false; readonly violation: string };

/**
 * Pull the first JSON object out of a raw completion and validate it.
 *
 * Small models fence their JSON, prefix it with prose, or emit it twice. Tolerating
 * that is legitimate — it is a decoding artefact, not a reasoning error. What is
 * NOT tolerated: a missing field, a value outside the enum, or evidence attached
 * to an `unknown`.
 */
export function parseAnswer(raw: string, expectedCriterion: CriterionId): ParseOutcome {
  const json = extractJsonObject(raw);
  if (json === null) return { ok: false, violation: "no JSON object in response" };

  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    return { ok: false, violation: "JSON did not parse" };
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return { ok: false, violation: "response was not a JSON object" };
  }

  const record = parsed as Record<string, unknown>;
  const value = record["value"];
  if (typeof value !== "string" || !VALUES.has(value)) {
    return { ok: false, violation: `value ${JSON.stringify(value)} is outside the enum` };
  }

  const criterion = record["criterion"];
  if (typeof criterion !== "string" || !CRITERIA_BY_ID.has(criterion as CriterionId)) {
    return { ok: false, violation: `criterion ${JSON.stringify(criterion)} is not a known criterion` };
  }
  if (criterion !== expectedCriterion) {
    return { ok: false, violation: `answered for ${criterion}, was asked ${expectedCriterion}` };
  }

  const evidenceRaw = record["evidence"];
  if (evidenceRaw !== null && typeof evidenceRaw !== "string") {
    return { ok: false, violation: "evidence was neither a string nor null" };
  }
  const evidence = typeof evidenceRaw === "string" && evidenceRaw.trim() !== "" ? evidenceRaw : null;

  // An abstention with a citation is a model talking itself into an answer it
  // then declined to give. Treat it as a violation so it stays visible.
  if (value === "unknown" && evidence !== null) {
    return { ok: false, violation: "cited evidence for an 'unknown' answer" };
  }
  if (value !== "unknown" && evidence === null) {
    return { ok: false, violation: `answered '${value}' without citing evidence` };
  }

  return {
    ok: true,
    answer: { criterion: criterion as CriterionId, value: value as CriterionValue, evidence },
  };
}

/** First balanced `{...}` in the text, ignoring braces inside JSON strings. */
function extractJsonObject(raw: string): string | null {
  const start = raw.indexOf("{");
  if (start === -1) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < raw.length; i += 1) {
    const char = raw[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === "\\") {
      escaped = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (char === "{") depth += 1;
    if (char === "}") {
      depth -= 1;
      if (depth === 0) return raw.slice(start, i + 1);
    }
  }
  return null;
}
