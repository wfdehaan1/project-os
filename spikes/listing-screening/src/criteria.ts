import type { Criterion, CriterionId } from "./types.ts";

/**
 * Three criteria, chosen to span the difficulty range rather than to cover the
 * user's real criteria set. Each isolates a different failure mode.
 */
export const CRITERIA: readonly Criterion[] = [
  {
    id: "warranty_included",
    question:
      "Is er garantie inbegrepen in de vraagprijs van deze auto, bovenop de wettelijke garantie? " +
      "Antwoord 'yes' alleen als de garantie zonder meerprijs bij de vraagprijs zit. " +
      "Antwoord 'no' als garantie alleen tegen meerprijs of als optioneel afleverpakket wordt aangeboden, " +
      "of als de advertentie expliciet zegt dat de prijs zonder garantie is. " +
      "Antwoord 'unknown' als de advertentie er niets over zegt of zichzelf tegenspreekt.",
    rationale:
      "The criterion the user's own verdicts turn on most often, and the one the " +
      "structured field gets wrong 4 times in 10. The answer lives in Dutch prose " +
      "that routinely names a 12-month BOVAG warranty in the same paragraph that " +
      "says the asking price excludes it. This is the whole reason a model is here.",
    structurallyAvailable: "unreliable",
  },
  {
    id: "reversing_camera",
    question:
      "Heeft deze auto een achteruitrijcamera (parkeercamera)? " +
      "Antwoord 'yes' of 'no' alleen op basis van wat er staat, en 'unknown' als het er niet staat.",
    rationale:
      "The control. AutoScout24's equipment list answers it outright, so in `full` " +
      "mode a correct model agrees with the structured field, and in `text_only` " +
      "mode most cases become abstentions. A model that guesses here guesses everywhere.",
    structurallyAvailable: "yes",
  },
  {
    id: "leather_upholstery",
    question:
      "Heeft deze auto lederen bekleding? " +
      "Antwoord 'yes' of 'no' alleen op basis van wat er staat, en 'unknown' als het er niet staat.",
    rationale:
      "The floor. A single structured field states it, and the description usually " +
      "repeats it. If a model fails this, nothing else in the report matters.",
    structurallyAvailable: "yes",
  },
];

export const CRITERIA_BY_ID: ReadonlyMap<CriterionId, Criterion> = new Map(
  CRITERIA.map((criterion) => [criterion.id, criterion]),
);
