/**
 * Fixture and label loading. Node-only; the pure logic lives in schema.ts,
 * prompt.ts, baseline.ts and grade.ts.
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import type { Case, CriterionId, CriterionValue, Label, RecordedResponse } from "./types.ts";

const here = dirname(fileURLToPath(import.meta.url));
export const ROOT = resolve(here, "..");

/**
 * A 30-line CSV reader, duplicated from the matcher spike on purpose. Two
 * throwaway spikes sharing a module would couple them for the sake of one
 * function neither will keep.
 */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (quoted) {
      if (char === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          quoted = false;
        }
      } else {
        field += char;
      }
      continue;
    }
    if (char === '"') {
      quoted = true;
      continue;
    }
    if (char === ",") {
      row.push(field);
      field = "";
      continue;
    }
    if (char === "\n" || char === "\r") {
      if (char === "\r" && text[i + 1] === "\n") i += 1;
      row.push(field);
      field = "";
      if (row.length > 1 || row[0] !== "") rows.push(row);
      row = [];
      continue;
    }
    field += char;
  }
  row.push(field);
  if (row.length > 1 || row[0] !== "") rows.push(row);
  return rows;
}

export function loadCases(path = resolve(ROOT, "fixtures/cases.json")): Case[] {
  return JSON.parse(readFileSync(path, "utf8")) as Case[];
}

export function loadLabels(path = resolve(ROOT, "labels.csv")): Label[] {
  const rows = parseCsv(readFileSync(path, "utf8"));
  return rows.slice(1).map((row) => ({
    id: row[0] ?? "",
    criterion: (row[1] ?? "") as CriterionId,
    expected: (row[2] ?? "unknown") as CriterionValue,
    provenance: (row[3] ?? "text") as Label["provenance"],
    note: row[4] ?? "",
  }));
}

export const labelKey = (id: string, criterion: string): string => `${id}::${criterion}`;

export function labelIndex(labels: readonly Label[]): Map<string, Label> {
  return new Map(labels.map((label) => [labelKey(label.id, label.criterion), label]));
}

/** JSONL, one RecordedResponse per line. Blank lines and `#` comments are skipped. */
export function loadResponses(path: string): RecordedResponse[] {
  return readFileSync(path, "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "" && !line.startsWith("#"))
    .map((line) => JSON.parse(line) as RecordedResponse);
}
