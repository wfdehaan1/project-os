import type { AllowanceValidationEvidence } from "./allowance-evidence-schema.ts";

const FORBIDDEN = /token|secret|authorization|api[_-]?key|account(?:id|_id)?|https?:\/\/|\/(?:Users|tmp|private|var)\/|prompt|payload|event(?:name|type)?/iu;
export function sanitizeAllowanceEvidence(evidence: AllowanceValidationEvidence): AllowanceValidationEvidence {
  if (FORBIDDEN.test(JSON.stringify(evidence)) || evidence.buckets.some((bucket) =>
    !Number.isFinite(bucket.usedPercent) || bucket.usedPercent < 0 || bucket.usedPercent > 100 ||
    !Number.isSafeInteger(bucket.windowDurationMinutes) || bucket.windowDurationMinutes < 1 ||
    !(bucket.resetsAt === null || validTimestamp(bucket.resetsAt)))) throw new Error("evidence_write_failed");
  return Object.freeze({ ...evidence, buckets: Object.freeze(evidence.buckets.map((bucket) => Object.freeze({ ...bucket }))), remedy: evidence.remedy ? Object.freeze({ ...evidence.remedy }) : null });
}

function validTimestamp(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString() === value;
}
