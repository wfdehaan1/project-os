import { randomUUID } from "node:crypto";
import { createConversation, type Conversation } from "./conversation-ownership.ts";
import { parsePortableProjectExport, type PortableProjectBody, type PortableProjectExport, type ProjectImportProvenance, type ProjectOwnedState } from "./project-export.ts";

export interface RestoredProject {
  readonly project: ProjectOwnedState;
  readonly importProvenance: ProjectImportProvenance;
}
export interface RestoreOptions { readonly makeId?: (sourceId: string, ordinal: number) => string; }

/** Preflight is pure and completes before one new local Project is returned. */
export function preflightPortableProject(value: unknown): PortableProjectExport {
  if (isRecord(value) && value.schemaVersion === 0) return migrateV0(value);
  return parsePortableProjectExport(value);
}

/**
 * Restore deliberately has no adapter input/import. It produces one completely
 * new local identity graph and starts with an empty side-car binding list.
 */
export function restorePortableProject(value: unknown, options: RestoreOptions = {}): RestoredProject {
  const portable = preflightPortableProject(value);
  const source = portable.project;
  const sourceIds = collectIds(source);
  const map = createIdMap(sourceIds, options.makeId);
  const remap = (id: string): string => {
    const mapped = map.get(id); if (!mapped) throw new Error("restore_map_incomplete"); return mapped;
  };
  const conversations = source.conversations.map((conversation) => createConversation({
    id: remap(conversation.id), version: conversation.version,
    transcript: conversation.transcript.map((entry) => ({ ...entry, id: remap(entry.id) })),
    acceptedHistory: conversation.acceptedHistory.map((entry) => ({ ...entry, id: remap(entry.id), transcriptEntryId: remap(entry.transcriptEntryId) })),
  }));
  const project: ProjectOwnedState = Object.freeze({
    id: remap(source.id), version: source.version, conversations: Object.freeze(conversations),
    importProvenance: Object.freeze({ sourceProjectId: source.importProvenance?.sourceProjectId ?? source.id, originalIds: Object.freeze([...map.entries()].map(([original, restored]) => Object.freeze({ restoredId: restored, originalId: source.importProvenance?.originalIds.find((entry) => entry.restoredId === original)?.originalId ?? original }))) }),
    rationales: Object.freeze(source.rationales.map((item) => Object.freeze({ ...item, id: remap(item.id), conversationId: remap(item.conversationId) }))),
    provenances: Object.freeze(source.provenances.map((item) => Object.freeze({ ...item, id: remap(item.id), sourceId: remap(item.sourceId), conversationId: remap(item.conversationId) }))),
    sources: Object.freeze(source.sources.map((item) => Object.freeze({ ...item, id: remap(item.id) }))),
    relationships: Object.freeze(source.relationships.map((item) => Object.freeze({ ...item, id: remap(item.id), fromId: remap(item.fromId), toId: remap(item.toId) }))),
    bindings: Object.freeze([]),
  });
  return Object.freeze({ project, importProvenance: project.importProvenance! });
}

function migrateV0(value: Record<string, unknown>): PortableProjectExport {
  // v0 allowed an adapter-metadata envelope. It is intentionally ignored, not
  // translated: it has no route to the restored Project or a future binding.
  if (!exactKeys(value, ["adapterMetadata", "project", "schemaVersion"]) || !isRecord(value.project)) throw new Error("portable_project_invalid");
  return parsePortableProjectExport({ schemaVersion: 1, project: { ...value.project, importProvenance: null } });
}

function collectIds(project: PortableProjectBody): readonly string[] {
  return [project.id, ...project.conversations.flatMap((conversation) => [conversation.id, ...conversation.transcript.map((entry) => entry.id), ...conversation.acceptedHistory.map((entry) => entry.id)]), ...project.rationales.map((item) => item.id), ...project.provenances.map((item) => item.id), ...project.sources.map((item) => item.id), ...project.relationships.map((item) => item.id)];
}

function createIdMap(ids: readonly string[], factory: RestoreOptions["makeId"]): ReadonlyMap<string, string> {
  if (new Set(ids).size !== ids.length) throw new Error("portable_project_invalid");
  const map = new Map<string, string>(); const generated = new Set<string>();
  for (const [index, sourceId] of ids.entries()) {
    const restored = factory ? factory(sourceId, index + 1) : `restore-${randomUUID()}-${index + 1}`;
    if (!/^[A-Za-z][A-Za-z0-9._-]{0,127}$/u.test(restored) || generated.has(restored) || ids.includes(restored)) throw new Error("restore_map_invalid");
    map.set(sourceId, restored); generated.add(restored);
  }
  return map;
}
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function exactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean { const keys = Object.keys(value).sort(); return keys.length === expected.length && keys.every((key, index) => key === expected[index]); }
