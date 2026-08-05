import { readFile } from "node:fs/promises";
import { REQUIRED_GATE_IDS } from "./gate-decision-evidence-schema.ts";
import type { GateDecisionEvidence, GateDecision, GateId, GateResult, GateSourceManifest, GateSourceRecord } from "./gate-decision-evidence-schema.ts";
import { exactKeys, readPinnedJson, safeCode, safeFileName, sha256 } from "./gate-decision-source-verify.ts";

const bundleBrand = new WeakSet<object>();
const syntheticBundleBrand = new WeakSet<object>();
export interface ValidatedBundle { readonly manifestSha256: string; readonly records: Readonly<Record<GateId, GateSourceRecord>>; }

export async function loadValidatedGateEvidence(root: string): Promise<ValidatedBundle> {
  const approved = parseManifest(JSON.parse(await readFile(new URL("../../evidence/approved-current-gate-manifest.json", import.meta.url), "utf8")));
  const manifestInput = await readPinnedJson(root, "gate-decision-sources.json");
  const manifest = parseManifest(manifestInput.value);
  const manifestSha256 = sha256(canonical(manifest));
  if (manifestSha256 !== sha256(canonical(approved))) throw new Error("unapproved_evidence_manifest");
  const records = {} as Record<GateId, GateSourceRecord>;
  for (const gate of REQUIRED_GATE_IDS) {
    const expected = manifest.records[gate];
    if (!expected || !safeFileName(expected.file)) throw new Error("incomplete_evidence_bundle");
    const input = await readPinnedJson(root, expected.file);
    if (sha256(input.text) !== expected.sha256) throw new Error("evidence_digest_mismatch");
    const record = parseRecord(input.value);
    if (record.gate !== gate || record.reproductionCommand !== expected.reproductionCommand) throw new Error("evidence_identity_mismatch");
    records[gate] = record;
  }
  const bundle = Object.freeze({ manifestSha256, records: Object.freeze(records) }); bundleBrand.add(bundle); return bundle;
}

export function reduceGateDecision(bundle: ValidatedBundle): GateDecisionEvidence {
  if (!bundleBrand.has(bundle) || !bundle.records || Object.keys(bundle.records).length !== REQUIRED_GATE_IDS.length) throw new Error("unvalidated_evidence_bundle");
  const records = REQUIRED_GATE_IDS.map((gate) => bundle.records[gate]);
  if (records.some((record) => !record)) throw new Error("incomplete_evidence_bundle");
  const failedGates = REQUIRED_GATE_IDS.filter((gate) => bundle.records[gate].result === "failed");
  const constrained = REQUIRED_GATE_IDS.some((gate) => bundle.records[gate].result === "constrained");
  const decision: GateDecision = failedGates.length ? "reject" : constrained ? "proceed_with_constraints" : "proceed";
  const stopConditions = Object.freeze(REQUIRED_GATE_IDS.filter((gate) => bundle.records[gate].result !== "passed").map((gate) => bundle.records[gate].safeCode!).sort());
  if ((decision === "reject" && stopConditions.length < failedGates.length) || (decision === "proceed" && stopConditions.length !== 0)) throw new Error("contradictory_gate_decision");
  return Object.freeze({ schemaVersion: 1, runId: "reduced", decision, failedGates: Object.freeze(failedGates), stopConditions, sourceManifestSha256: bundle.manifestSha256, reproductionCommand: "npm run validate:gate-decision" });
}

/** Test-only reducer input. It is branded by this module but cannot be published. */
export function createSyntheticGateEvidenceForTest(recordsInput: Readonly<Record<GateId, GateSourceRecord>>): ValidatedBundle {
  const records = {} as Record<GateId, GateSourceRecord>;
  for (const gate of REQUIRED_GATE_IDS) {
    const record = parseRecord(recordsInput[gate]);
    if (record.gate !== gate) throw new Error("invalid_evidence_record");
    records[gate] = record;
  }
  if (Object.keys(recordsInput).length !== REQUIRED_GATE_IDS.length) throw new Error("incomplete_evidence_bundle");
  const bundle = Object.freeze({ manifestSha256: "0".repeat(64), records: Object.freeze(records) });
  bundleBrand.add(bundle); syntheticBundleBrand.add(bundle); return bundle;
}

export function assertApprovedGateEvidenceBundle(bundle: ValidatedBundle): void {
  if (!bundleBrand.has(bundle) || syntheticBundleBrand.has(bundle)) throw new Error("unvalidated_evidence_bundle");
}

function parseManifest(value: unknown): GateSourceManifest {
  if (!exactKeys(value, ["schemaVersion", "records"]) || value.schemaVersion !== 1 || !value.records || typeof value.records !== "object" || Array.isArray(value.records) || Object.keys(value.records).length !== REQUIRED_GATE_IDS.length) throw new Error("invalid_evidence_manifest");
  const records = {} as Record<GateId, { readonly file: string; readonly sha256: string; readonly reproductionCommand: string }>;
  for (const gate of REQUIRED_GATE_IDS) {
    const item = (value.records as Record<string, unknown>)[gate];
    if (!exactKeys(item, ["file", "sha256", "reproductionCommand"]) || typeof item.file !== "string" || !safeFileName(item.file) || typeof item.sha256 !== "string" || !/^[a-f0-9]{64}$/u.test(item.sha256) || typeof item.reproductionCommand !== "string" || !/^npm run [a-z0-9:_-]{2,80}$/u.test(item.reproductionCommand)) throw new Error("invalid_evidence_manifest");
    records[gate] = Object.freeze({ file: item.file, sha256: item.sha256, reproductionCommand: item.reproductionCommand });
  }
  return Object.freeze({ schemaVersion: 1, records: Object.freeze(records) });
}
function parseRecord(value: unknown): GateSourceRecord {
  if (!exactKeys(value, ["schemaVersion", "gate", "result", "safeCode", "reproductionCommand"]) || value.schemaVersion !== 1 || !REQUIRED_GATE_IDS.includes(value.gate as GateId) || !["passed", "constrained", "failed"].includes(value.result as GateResult) || typeof value.reproductionCommand !== "string" || !/^npm run [a-z0-9:_-]{2,80}$/u.test(value.reproductionCommand) || (value.result === "passed" ? value.safeCode !== null : !safeCode(value.safeCode))) throw new Error("invalid_evidence_record");
  return Object.freeze({ schemaVersion: 1, gate: value.gate as GateId, result: value.result as GateResult, safeCode: value.safeCode as string | null, reproductionCommand: value.reproductionCommand });
}
function canonical(value: unknown): string { return JSON.stringify(value); }
