/** ProjectOS-owned schema and wire-independent representation of validation proposals. */
export const CHANGE_PROPOSAL_SCHEMA = Object.freeze({
  $schema: "https://json-schema.org/draft/2020-12/schema",
  type: "object",
  additionalProperties: false,
  required: ["proposalId", "artifacts", "relationships", "governingEffects", "reentryEffects"],
  properties: {
    proposalId: { type: "string", pattern: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$" },
    artifacts: { type: "array", minItems: 1, maxItems: 64 },
    relationships: { type: "array", maxItems: 128 },
    governingEffects: { type: "array", maxItems: 32 },
    reentryEffects: { type: "array", maxItems: 32 },
  },
});

export type ProposalArtifactType = "fact" | "decision" | "research" | "open_question" | "task";

export interface ContextPreview {
  readonly previewId: string;
  /** Explicitly selected labels only; no filesystem path, repository, or ambient context. */
  readonly records: readonly { readonly id: string; readonly type: ProposalArtifactType; readonly summary: string }[];
}

export interface ChangeProposal {
  readonly proposalId: string;
  readonly artifacts: readonly {
    readonly id: string;
    readonly type: ProposalArtifactType;
    readonly provenance: readonly string[];
  }[];
  readonly relationships: readonly { readonly from: string; readonly to: string; readonly kind: string }[];
  readonly governingEffects: readonly string[];
  readonly reentryEffects: readonly string[];
}

export function validateContextPreview(value: unknown): value is ContextPreview {
  if (!object(value) || !safeId(value.previewId) || !Array.isArray(value.records) || value.records.length < 1 || value.records.length > 64) return false;
  return value.records.every((record) => object(record) && safeId(record.id) && artifactType(record.type) && safeSummary(record.summary));
}

/** Reject rather than coerce. The provider's JSON can never become ProjectOS state by parsing alone. */
export function validateChangeProposal(value: unknown): value is ChangeProposal {
  if (!object(value) || !exactKeys(value, ["proposalId", "artifacts", "relationships", "governingEffects", "reentryEffects"]) || !safeId(value.proposalId) || !Array.isArray(value.artifacts) || value.artifacts.length < 1 || value.artifacts.length > 64 || !Array.isArray(value.relationships) || !Array.isArray(value.governingEffects) || !Array.isArray(value.reentryEffects)) return false;
  const artifactIds = new Set<string>();
  for (const artifact of value.artifacts) {
    if (!object(artifact) || !exactKeys(artifact, ["id", "type", "provenance"]) || !safeId(artifact.id) || artifactIds.has(artifact.id) || !artifactType(artifact.type) || !Array.isArray(artifact.provenance) || artifact.provenance.length < 1 || artifact.provenance.length > 16 || !artifact.provenance.every(safeId)) return false;
    artifactIds.add(artifact.id);
  }
  return value.relationships.length <= 128 && value.relationships.every((relationship) => object(relationship) && exactKeys(relationship, ["from", "to", "kind"]) && typeof relationship.from === "string" && artifactIds.has(relationship.from) && typeof relationship.to === "string" && artifactIds.has(relationship.to) && safeLabel(relationship.kind)) && value.governingEffects.length <= 32 && value.governingEffects.every(safeLabel) && value.reentryEffects.length <= 32 && value.reentryEffects.every(safeLabel);
}

function object(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function exactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean { const keys = Object.keys(value).sort(); return keys.length === expected.length && keys.every((key, index) => key === [...expected].sort()[index]); }
function safeId(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/u.test(value); }
function safeLabel(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9 .,_-]{0,159}$/u.test(value); }
function safeSummary(value: unknown): value is string { return typeof value === "string" && value.length > 0 && value.length <= 1_000 && !/[\\/\u0000-\u001f]/u.test(value); }
function artifactType(value: unknown): value is ProposalArtifactType { return value === "fact" || value === "decision" || value === "research" || value === "open_question" || value === "task"; }
