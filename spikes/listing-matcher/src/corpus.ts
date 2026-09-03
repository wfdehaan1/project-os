/**
 * Corpus loading. Node-only — this is the harness half of the spike and is the
 * one file that does NOT port to Swift. Everything under test stays pure.
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import type { Listing } from "./types.ts";

const here = dirname(fileURLToPath(import.meta.url));
export const CORPUS_DIR = resolve(here, "../../listing-corpus");

export type Relation = "same_car" | "same_variant_diff_car" | "different";

export interface LabelledPair {
  readonly idA: string;
  readonly idB: string;
  readonly relation: Relation;
  readonly howKnown: string;
}

/** RFC 4180 enough for the corpus: quoted fields, doubled quotes, embedded commas. */
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

function records(text: string): Array<Record<string, string>> {
  const rows = parseCsv(text);
  const header = rows[0];
  if (header === undefined) return [];
  return rows
    .slice(1)
    .map((row) => Object.fromEntries(header.map((key, index) => [key, row[index] ?? ""])));
}

const text = (value: string | undefined): string | null => {
  const trimmed = (value ?? "").trim();
  return trimmed === "" ? null : trimmed;
};

const number = (value: string | undefined): number | null => {
  const raw = text(value);
  if (raw === null) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
};

export function loadListings(path = resolve(CORPUS_DIR, "extracted.csv")): Listing[] {
  return records(readFileSync(path, "utf8")).map((row) => ({
    id: row["id"] ?? "",
    site: row["site"] ?? "",
    listingId: text(row["listing_id"]),
    capturedAt: text(row["captured_at"]),
    plate: text(row["plate"]),
    make: text(row["make"]),
    model: text(row["model"]),
    variant: text(row["variant"]),
    trim: text(row["trim_input"]),
    body: text(row["body"]),
    firstRegistration: text(row["first_reg"]),
    mileageKm: number(row["mileage_km"]),
    priceEur: number(row["price_eur"]),
    fuel: text(row["fuel"]),
    transmission: text(row["transmission"]),
    powerHp: number(row["power_hp"]),
    color: text(row["color"]),
    upholstery: text(row["upholstery"]),
    doors: number(row["doors"]),
    sellerName: text(row["seller_name"]),
    sellerCity: text(row["seller_city"]),
  }));
}

export function loadPairs(path = resolve(CORPUS_DIR, "pairs.csv")): LabelledPair[] {
  return records(readFileSync(path, "utf8"))
    .filter((row) => text(row["id_a"]) !== null && text(row["id_b"]) !== null)
    .map((row) => ({
      idA: row["id_a"] ?? "",
      idB: row["id_b"] ?? "",
      relation: (row["relation"] ?? "different") as Relation,
      howKnown: row["how_known"] ?? "",
    }));
}

/** Stable key for a pair, order-independent. */
export const pairKey = (a: string, b: string): string => (a < b ? `${a} ${b}` : `${b} ${a}`);

/**
 * The ground truth for every pair, not just the labelled ones. `pairs.csv` is
 * sparse by design (README: "anything not listed is treated as different"), so
 * unlabelled pairs are the negative class.
 */
export function truthFor(pairs: readonly LabelledPair[]): Map<string, Relation> {
  return new Map(pairs.map((pair) => [pairKey(pair.idA, pair.idB), pair.relation]));
}
