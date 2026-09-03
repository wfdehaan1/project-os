/**
 * Vocabulary for the screening spike (D16).
 *
 * As with the matcher, everything here maps to a Swift struct or enum: the
 * screening contract is part of the "hard logic stays pure" clause in D19.3.
 */

/**
 * The three-valued answer D10 requires. `unknown` is a first-class, *correct*
 * answer — "reversing camera: not stated" is useful; "probably yes" is the
 * failure mode that destroys trust.
 */
export type CriterionValue = "yes" | "no" | "unknown";

export type CriterionId = "warranty_included" | "reversing_camera" | "leather_upholstery";

export interface Criterion {
  readonly id: CriterionId;
  /** Put to the model verbatim. Phrasing is the experiment; keep it in one place. */
  readonly question: string;
  /** What makes this criterion worth testing — see README. */
  readonly rationale: string;
  /** Whether the page answers it structurally, and therefore what `full` mode should be able to do. */
  readonly structurallyAvailable: "yes" | "no" | "unreliable";
}

/** One listing, as the fixture builder emits it. */
export interface Case {
  readonly id: string;
  readonly site: string;
  readonly description: string;
  readonly structured: Readonly<Record<string, unknown>>;
}

/** A row of labels.csv. */
export interface Label {
  readonly id: string;
  readonly criterion: CriterionId;
  readonly expected: CriterionValue;
  /**
   * Where the label came from, so a disagreement can be traced rather than
   * argued about. `disputed` means the prose and the recorded verdict conflict.
   */
  readonly provenance: "user" | "text" | "structured" | "both" | "disputed";
  readonly note: string;
}

/** What `full` mode gives the model versus what `text_only` withholds. */
export type PromptMode = "full" | "text_only";

/** The strict output shape. A response that does not parse to this is a schema violation, not a wrong answer. */
export interface ScreeningAnswer {
  readonly criterion: CriterionId;
  readonly value: CriterionValue;
  /**
   * The span the model is relying on, quoted from the input. Required for `yes`
   * and `no`, and must be null for `unknown` — a model that cites evidence for
   * an abstention is confabulating.
   */
  readonly evidence: string | null;
}

/** One model response as recorded by a runner. */
export interface RecordedResponse {
  readonly id: string;
  readonly criterion: CriterionId;
  readonly mode: PromptMode;
  /** Raw model text, exactly as returned. Parsed here, not by the runner. */
  readonly raw: string;
  /** Optional runner metadata: model name, latency, token counts. */
  readonly meta?: Readonly<Record<string, unknown>>;
}
