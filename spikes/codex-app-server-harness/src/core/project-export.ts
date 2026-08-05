import { createHash } from "node:crypto";
import { createConversation, isBinding, isSafeId, type Conversation, type ProviderSessionBinding } from "./conversation-ownership.ts";

export const PORTABLE_PROJECT_SCHEMA_VERSION = 1 as const;

export interface ProjectRationale { readonly id: string; readonly conversationId: string; readonly version: number; readonly statement: string; }
export interface ProjectProvenance { readonly id: string; readonly sourceId: string; readonly conversationId: string; readonly version: number; readonly note: string; }
export interface ProjectSource { readonly id: string; readonly version: number; readonly label: string; }
export interface ProjectRelationship { readonly id: string; readonly fromId: string; readonly toId: string; readonly kind: string; readonly version: number; }
export interface ProjectImportProvenance { readonly sourceProjectId: string; readonly originalIds: readonly { readonly restoredId: string; readonly originalId: string }[]; }
export interface ProjectOwnedState {
  readonly id: string;
  readonly version: number;
  readonly importProvenance: ProjectImportProvenance | null;
  readonly conversations: readonly Conversation[];
  readonly rationales: readonly ProjectRationale[];
  readonly provenances: readonly ProjectProvenance[];
  readonly sources: readonly ProjectSource[];
  readonly relationships: readonly ProjectRelationship[];
  readonly bindings: readonly ProviderSessionBinding[];
}
export interface PortableProjectBody { readonly id: string; readonly version: number; readonly importProvenance: ProjectImportProvenance | null; readonly conversations: readonly Conversation[]; readonly rationales: readonly ProjectRationale[]; readonly provenances: readonly ProjectProvenance[]; readonly sources: readonly ProjectSource[]; readonly relationships: readonly ProjectRelationship[]; }
export interface PortableProjectExport { readonly schemaVersion: 1; readonly project: PortableProjectBody; }

/** Exact-shape export: bindings are validated in local state then intentionally omitted. */
export function exportPortableProject(state: ProjectOwnedState): PortableProjectExport {
  const project = validateProjectState(state);
  return Object.freeze({ schemaVersion: PORTABLE_PROJECT_SCHEMA_VERSION, project: freezePortableBody(project) });
}

export function parsePortableProjectExport(value: unknown): PortableProjectExport {
  if (!record(value) || !exactKeys(value, ["project", "schemaVersion"]) || value.schemaVersion !== PORTABLE_PROJECT_SCHEMA_VERSION || !record(value.project)) throw new Error("portable_project_invalid");
  return Object.freeze({ schemaVersion: PORTABLE_PROJECT_SCHEMA_VERSION, project: freezePortableBody(validatePortableBody(value.project, false)) });
}

export function portableProjectDigest(value: PortableProjectExport): string {
  return createHash("sha256").update(canonicalJson(canonicalPortableProject(parsePortableProjectExport(value)))).digest("hex");
}

export function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (record(value)) return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

export function validateProjectState(value: unknown): PortableProjectBody {
  if (!record(value) || !exactKeys(value, ["bindings", "conversations", "id", "importProvenance", "provenances", "rationales", "relationships", "sources", "version"])) throw new Error("project_state_invalid");
  if (!Array.isArray(value.bindings) || !value.bindings.every(isBinding)) throw new Error("project_state_invalid");
  const body = validatePortableBody(value, true);
  const conversationIds = new Set(body.conversations.map((conversation) => conversation.id));
  if (!value.bindings.every((binding) => conversationIds.has(binding.conversationId))) throw new Error("project_state_invalid");
  const bindingKeys = value.bindings.map((binding) => `${binding.adapterId}\u0000${binding.conversationId}`);
  if (new Set(bindingKeys).size !== bindingKeys.length) throw new Error("project_state_invalid");
  return body;
}

function validatePortableBody(value: Record<string, unknown>, acceptsBindings: boolean): PortableProjectBody {
  if (!exactKeys(value, acceptsBindings ? ["bindings", "conversations", "id", "importProvenance", "provenances", "rationales", "relationships", "sources", "version"] : ["conversations", "id", "importProvenance", "provenances", "rationales", "relationships", "sources", "version"])) throw new Error("portable_project_invalid");
  if (!isSafeId(value.id) || !positive(value.version) || !Array.isArray(value.conversations) || !Array.isArray(value.rationales) || !Array.isArray(value.provenances) || !Array.isArray(value.sources) || !Array.isArray(value.relationships)) throw new Error("portable_project_invalid");
  const conversations = value.conversations.map((item) => createConversation(item as Conversation));
  const rationales = value.rationales.map(rationale); const provenances = value.provenances.map(provenance); const sources = value.sources.map(source); const relationships = value.relationships.map(relationship);
  const allIds = [value.id, ...conversations.flatMap((item) => [item.id, ...item.transcript.map((entry) => entry.id), ...item.acceptedHistory.map((entry) => entry.id)]), ...rationales.map((item) => item.id), ...provenances.map((item) => item.id), ...sources.map((item) => item.id), ...relationships.map((item) => item.id)];
  if (new Set(allIds).size !== allIds.length) throw new Error("portable_project_invalid");
  const conversationIds = new Set(conversations.map((item) => item.id)); const sourceIds = new Set(sources.map((item) => item.id)); const ownedIds = new Set(allIds);
  if (!rationales.every((item) => conversationIds.has(item.conversationId)) || !provenances.every((item) => conversationIds.has(item.conversationId) && sourceIds.has(item.sourceId)) || !relationships.every((item) => ownedIds.has(item.fromId) && ownedIds.has(item.toId))) throw new Error("portable_project_invalid");
  const importProvenance = provenanceMap(value.importProvenance, ownedIds);
  return { id: value.id, version: value.version, importProvenance, conversations, rationales, provenances, sources, relationships };
}

function rationale(value: unknown): ProjectRationale { if (!record(value) || !exactKeys(value, ["conversationId", "id", "statement", "version"]) || !isSafeId(value.id) || !isSafeId(value.conversationId) || !positive(value.version) || !safeText(value.statement)) throw new Error("portable_project_invalid"); return Object.freeze({ id: value.id, conversationId: value.conversationId, version: value.version, statement: value.statement }); }
function provenance(value: unknown): ProjectProvenance { if (!record(value) || !exactKeys(value, ["conversationId", "id", "note", "sourceId", "version"]) || !isSafeId(value.id) || !isSafeId(value.sourceId) || !isSafeId(value.conversationId) || !positive(value.version) || !safeText(value.note)) throw new Error("portable_project_invalid"); return Object.freeze({ id: value.id, sourceId: value.sourceId, conversationId: value.conversationId, version: value.version, note: value.note }); }
function source(value: unknown): ProjectSource { if (!record(value) || !exactKeys(value, ["id", "label", "version"]) || !isSafeId(value.id) || !positive(value.version) || !safeText(value.label)) throw new Error("portable_project_invalid"); return Object.freeze({ id: value.id, version: value.version, label: value.label }); }
function relationship(value: unknown): ProjectRelationship { if (!record(value) || !exactKeys(value, ["fromId", "id", "kind", "toId", "version"]) || !isSafeId(value.id) || !isSafeId(value.fromId) || !isSafeId(value.toId) || !positive(value.version) || !safeLabel(value.kind)) throw new Error("portable_project_invalid"); return Object.freeze({ id: value.id, fromId: value.fromId, toId: value.toId, kind: value.kind, version: value.version }); }
function provenanceMap(value: unknown, ownedIds: ReadonlySet<string>): ProjectImportProvenance | null { if (value === null) return null; if (!record(value) || !exactKeys(value, ["originalIds", "sourceProjectId"]) || !isSafeId(value.sourceProjectId) || !Array.isArray(value.originalIds)) throw new Error("portable_project_invalid"); const originalIds = value.originalIds.map((entry) => { if (!record(entry) || !exactKeys(entry, ["originalId", "restoredId"]) || !isSafeId(entry.restoredId) || !isSafeId(entry.originalId) || !ownedIds.has(entry.restoredId)) throw new Error("portable_project_invalid"); return Object.freeze({ restoredId: entry.restoredId, originalId: entry.originalId }); }); if (originalIds.length !== ownedIds.size || new Set(originalIds.map((entry) => entry.restoredId)).size !== originalIds.length || new Set(originalIds.map((entry) => entry.originalId)).size !== originalIds.length) throw new Error("portable_project_invalid"); return Object.freeze({ sourceProjectId: value.sourceProjectId, originalIds: Object.freeze(originalIds) }); }
function canonicalPortableProject(value: PortableProjectExport): PortableProjectExport { const project = value.project; return { schemaVersion: 1, project: { ...project, importProvenance: project.importProvenance === null ? null : { sourceProjectId: project.importProvenance.sourceProjectId, originalIds: [...project.importProvenance.originalIds].sort(by("restoredId")) }, conversations: [...project.conversations].sort(by("id")), rationales: [...project.rationales].sort(by("id")), provenances: [...project.provenances].sort(by("id")), sources: [...project.sources].sort(by("id")), relationships: [...project.relationships].sort(by("id")) } }; }
function by<K extends string>(key: K): <T extends Record<K, string>>(left: T, right: T) => number { return (left, right) => left[key].localeCompare(right[key]); }
function freezePortableBody(body: PortableProjectBody): PortableProjectBody { return Object.freeze({ ...body, importProvenance: body.importProvenance === null ? null : Object.freeze({ sourceProjectId: body.importProvenance.sourceProjectId, originalIds: Object.freeze(body.importProvenance.originalIds.map((item) => Object.freeze({ ...item }))) }), conversations: Object.freeze(body.conversations.map(createConversation)), rationales: Object.freeze(body.rationales.map((item) => Object.freeze({ ...item }))), provenances: Object.freeze(body.provenances.map((item) => Object.freeze({ ...item }))), sources: Object.freeze(body.sources.map((item) => Object.freeze({ ...item }))), relationships: Object.freeze(body.relationships.map((item) => Object.freeze({ ...item }))) }); }
function record(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function exactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean { const keys = Object.keys(value).sort(); return keys.length === expected.length && keys.every((key, index) => key === expected[index]); }
function positive(value: unknown): value is number { return typeof value === "number" && Number.isSafeInteger(value) && value > 0; }
function safeText(value: unknown): value is string { return typeof value === "string" && value.length > 0 && value.length <= 16_000 && !/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(value); }
function safeLabel(value: unknown): value is string { return typeof value === "string" && /^[A-Za-z0-9 .,_-]{1,159}$/u.test(value); }
