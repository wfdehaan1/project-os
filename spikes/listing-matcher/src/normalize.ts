/**
 * Normalisation. Pure string/number work, no locale APIs — `toLocaleLowerCase`
 * and `Intl` have no cheap Swift equivalent and would drift between ports.
 */

/** Fold accents, punctuation and case into a comparable token stream. */
export function fold(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

/**
 * Dutch plates are written `XX-123-Y`, but sellers type them a dozen ways and
 * one listing in the corpus carries an unpunctuated `HZV11j`. Strip everything
 * that is not alphanumeric and upper-case what is left.
 */
export function normalizePlate(plate: string | null): string | null {
  if (plate === null) return null;
  const stripped = plate.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
  // 6 characters is the Dutch format. Anything shorter is a capture artefact,
  // and treating it as a hard key would merge unrelated cars.
  return stripped.length === 6 ? stripped : null;
}

/**
 * Words that appear in nearly every listing of this segment and therefore carry
 * no discriminating power. Keeping them would let two unrelated grey V60s score
 * highly on trim overlap alone — exactly the D5 false positive.
 */
const TRIM_STOPWORDS = new Set([
  "aut", "automaat", "automatisch", "benzine", "diesel", "elektro", "hybride",
  "nl", "auto", "km", "pk", "nap", "dealer", "onderhouden", "garantie",
  "mnd", "maanden", "incl", "inclusief", "met", "en", "de", "het", "van",
]);

/** Tokenise a seller-authored trim line into discriminating tokens. */
export function trimTokens(trim: string | null): ReadonlySet<string> {
  if (trim === null) return new Set();
  const tokens = fold(trim)
    .split(" ")
    .filter((token) => token.length > 1 && !TRIM_STOPWORDS.has(token));
  return new Set(tokens);
}

/** |A ∩ B| / |A ∪ B|. Returns null when either side is empty — unknown, not zero. */
export function jaccard(a: ReadonlySet<string>, b: ReadonlySet<string>): number | null {
  if (a.size === 0 || b.size === 0) return null;
  let intersection = 0;
  for (const token of a) if (b.has(token)) intersection += 1;
  return intersection / (a.size + b.size - intersection);
}

/** Compare two folded strings for equality, treating either side missing as unknown. */
export function sameText(a: string | null, b: string | null): boolean | null {
  if (a === null || b === null) return null;
  const fa = fold(a);
  const fb = fold(b);
  if (fa === "" || fb === "") return null;
  return fa === fb;
}

/**
 * Dealer chains list the same stock under branch names that differ only by town
 * ("Jacob Schaap Emmeloord" vs "Jacob Schaap Heerenveen"). Reduce to the leading
 * words so the two read as one seller, which is what the same-seller check needs.
 */
export function sellerKey(name: string | null): string | null {
  if (name === null) return null;
  const words = fold(name)
    .split(" ")
    .filter((word) => word.length > 1 && !["bv", "b", "v", "nv"].includes(word));
  if (words.length === 0) return null;
  return words.slice(0, 2).join(" ");
}

/** Whole months between two `YYYY-MM-DD` dates, or null if either is unparseable. */
export function monthsBetween(a: string | null, b: string | null): number | null {
  const pa = parseYearMonth(a);
  const pb = parseYearMonth(b);
  if (pa === null || pb === null) return null;
  return Math.abs((pa.year - pb.year) * 12 + (pa.month - pb.month));
}

function parseYearMonth(value: string | null): { year: number; month: number } | null {
  if (value === null) return null;
  const match = /^(\d{4})-(\d{2})/.exec(value);
  if (match === null) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (!Number.isFinite(year) || !Number.isFinite(month)) return null;
  return { year, month };
}

/** Days from `a` to `b`, signed. Null when either timestamp is missing. */
export function daysBetween(a: string | null, b: string | null): number | null {
  if (a === null || b === null) return null;
  const ta = Date.parse(a);
  const tb = Date.parse(b);
  if (Number.isNaN(ta) || Number.isNaN(tb)) return null;
  return (tb - ta) / 86_400_000;
}
