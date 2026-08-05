import { createHash } from "node:crypto";
import { constants } from "node:fs";
import { lstat, open, realpath } from "node:fs/promises";
import { basename, join, resolve } from "node:path";

const FORBIDDEN = /token|secret|authorization|api[_-]?key|account|https?:\/\/|\/(?:Users|tmp|private|var)\/|prompt|raw[_-]?(?:payload|result|content)|canonical[_-]?state|opaque[_-]?(?:binding|session)|credential|identity|local[_-]?path/iu;

export function sha256(value: string | Uint8Array): string { return createHash("sha256").update(value).digest("hex"); }
export function safeEvidenceText(value: string): boolean { return value.length <= 16_384 && !FORBIDDEN.test(value) && !/[\u0000-\u001f]/u.test(value.replace(/[\n\r\t]/gu, "")); }
export function safeFileName(value: string): boolean { return /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.json$/u.test(value) && basename(value) === value; }

/** Read a bounded regular file without resolving a caller-controlled symlink. */
export async function readPinnedJson(root: string, name: string): Promise<{ readonly text: string; readonly value: unknown }> {
  if (!safeFileName(name)) throw new Error("unsafe_evidence_source");
  const rootMeta = await lstat(root);
  if (!rootMeta.isDirectory() || rootMeta.isSymbolicLink()) throw new Error("unsafe_evidence_root");
  const canonicalRoot = await realpath(root);
  const candidate = resolve(canonicalRoot, name);
  if (!candidate.startsWith(`${canonicalRoot}/`) || join(canonicalRoot, name) !== candidate) throw new Error("unsafe_evidence_source");
  const handle = await open(candidate, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const stat = await handle.stat();
    if (!stat.isFile() || stat.size < 2 || stat.size > 16_384) throw new Error("unsafe_evidence_source");
    const text = await handle.readFile({ encoding: "utf8" });
    if (!safeEvidenceText(text)) throw new Error("unsafe_evidence_source");
    const value: unknown = JSON.parse(text);
    return Object.freeze({ text, value });
  } finally { await handle.close(); }
}

export function exactKeys(value: unknown, keys: readonly string[]): value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const actual = Object.keys(value).sort(); const expected = [...keys].sort();
  return actual.length === expected.length && actual.every((key, index) => key === expected[index]);
}
export function safeCode(value: unknown): value is string { return typeof value === "string" && /^[a-z][a-z0-9_]{1,79}$/u.test(value) && !FORBIDDEN.test(value); }
