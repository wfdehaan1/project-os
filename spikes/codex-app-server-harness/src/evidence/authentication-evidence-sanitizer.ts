import type { AuthenticationValidationEvidence } from "./authentication-evidence-schema.ts";

const SENSITIVE = /token|secret|authorization|api[_-]?key|account(?:id|_id)?|https?:\/\/|auth\.json|\/Users\//iu;

export function sanitizeAuthenticationEvidence(
  evidence: AuthenticationValidationEvidence,
): AuthenticationValidationEvidence {
  // Structural types do not carry sensitive fields; this blocks accidental future additions.
  if (SENSITIVE.test(JSON.stringify(evidence))) throw new Error("credential_ownership_rejected");
  return Object.freeze({ ...evidence });
}
