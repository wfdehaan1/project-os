import { randomUUID } from "node:crypto";
import { constants } from "node:fs";
import { chmod, lstat, mkdir, open, realpath, rename, rm } from "node:fs/promises";
import { join } from "node:path";
import type { GateDecisionEvidence } from "./gate-decision-evidence-schema.ts";
import { REQUIRED_GATE_IDS } from "./gate-decision-evidence-schema.ts";
import { assertApprovedGateEvidenceBundle, reduceGateDecision, type ValidatedBundle } from "./gate-decision-evidence-loader.ts";

export interface GateDecisionPublication {
  readonly path: string;
  readonly durability: "durable" | "unknown";
  readonly decision: GateDecisionEvidence["decision"];
}

/** Publish a complete summary once. A post-rename sync failure never deletes it. */
export async function writeGateDecisionEvidence(bundle: ValidatedBundle, root: string, runId = `gate-${randomUUID()}`): Promise<GateDecisionPublication> {
  assertApprovedGateEvidenceBundle(bundle);
  const reduced = reduceGateDecision(bundle);
  const evidence = validateEvidence({ ...reduced, runId });
  const base = await privateRoot(root);
  const final = join(base, `${evidence.runId}-gate-decision`);
  let staging: string | undefined;
  let renamed = false;
  try {
    await lstat(final).then(() => { throw new Error("evidence_destination_exists"); }).catch((error: unknown) => {
      if (error instanceof Error && "code" in error && error.code === "ENOENT") return;
      throw error;
    });
    staging = join(base, `.${evidence.runId}-${randomUUID()}.tmp`);
    await mkdir(staging, { mode: 0o700 }); await chmod(staging, 0o700);
    const summary = join(staging, "gate-decision-summary.json");
    const handle = await open(summary, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY, 0o600);
    try { await handle.writeFile(`${JSON.stringify(evidence, null, 2)}\n`); await handle.sync(); } finally { await handle.close(); }
    await chmod(summary, 0o600);
    await syncDirectory(staging); // summary is durable before publication becomes visible.
    await rename(staging, final); renamed = true;
    try { await syncDirectory(base); }
    catch { return Object.freeze({ path: join(final, "gate-decision-summary.json"), durability: "unknown", decision: evidence.decision }); }
    return Object.freeze({ path: join(final, "gate-decision-summary.json"), durability: "durable", decision: evidence.decision });
  } catch (error) {
    if (!renamed && staging) await rm(staging, { recursive: true, force: true }).catch(() => {});
    throw error instanceof Error ? error : new Error("evidence_write_failed");
  }
}

function validateEvidence(value: GateDecisionEvidence): GateDecisionEvidence {
  if (value.schemaVersion !== 1 || !safeId(value.runId) || !/^[a-f0-9]{64}$/u.test(value.sourceManifestSha256) || value.reproductionCommand !== "npm run validate:gate-decision" || !Array.isArray(value.failedGates) || new Set(value.failedGates).size !== value.failedGates.length || value.failedGates.some((gate) => !REQUIRED_GATE_IDS.includes(gate)) || !Array.isArray(value.stopConditions) || value.stopConditions.some((code) => !safeCode(code))) throw new Error("invalid_gate_decision");
  if ((value.decision === "reject" && (value.failedGates.length === 0 || value.stopConditions.length < value.failedGates.length)) || (value.decision === "proceed_with_constraints" && (value.failedGates.length !== 0 || value.stopConditions.length === 0)) || (value.decision === "proceed" && (value.failedGates.length !== 0 || value.stopConditions.length !== 0))) throw new Error("contradictory_gate_decision");
  return Object.freeze({ ...value, failedGates: Object.freeze([...value.failedGates].sort()), stopConditions: Object.freeze([...value.stopConditions].sort()) });
}
async function privateRoot(root: string): Promise<string> { try { const metadata = await lstat(root); if (!metadata.isDirectory() || metadata.isSymbolicLink() || (metadata.mode & 0o077) !== 0) throw new Error("unsafe_evidence_root"); } catch (error: unknown) { if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error; await mkdir(root, { recursive: true, mode: 0o700 }); await chmod(root, 0o700); } return realpath(root); }
async function syncDirectory(path: string): Promise<void> { const handle = await open(path, constants.O_RDONLY); try { await handle.sync(); } finally { await handle.close(); } }
function safeId(value: string): boolean { return /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/u.test(value); }
function safeCode(value: string): boolean { return /^[a-z][a-z0-9_]{1,79}$/u.test(value); }
