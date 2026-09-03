/**
 * A deterministic keyword screener, so the model's score has a floor to beat.
 *
 * Without this, "the on-device model got 78%" is unreadable — it could be worse
 * than twenty lines of regex. If the baseline matches the model, D16 answers
 * itself in the cheapest possible direction and no model is needed for this
 * criterion at all.
 *
 * The rules encode what a careful reader does: an explicit exclusion beats an
 * inclusion, because Dutch dealer ads name the 12-month BOVAG package in the
 * same breath as saying the asking price excludes it.
 */
import type { Case, CriterionId, CriterionValue } from "./types.ts";

/** "prijs is zonder garantie", "meeneemprijs ... zonder BOVAG-garantie". */
const EXCLUDED =
  /(zonder|excl\.?|exclusief)\s+(?:\w+[-\s]){0,3}garantie|garantie\s+(?:is\s+)?niet\s+inbegrepen/i;

/** "Standaard (inbegrepen): 12 maanden BOVAG-garantie", "geleverd met 12 maanden garantie". */
const INCLUDED =
  /inbegrepen[^.\n]{0,80}garantie|garantie[^.\n]{0,40}inbegrepen|(?:geleverd|leveren|aangeboden)[^.\n]{0,60}\d{1,2}\s*maanden[^.\n]{0,20}garantie|inclusief[^.\n]{0,40}garantie/i;

/** "optioneel", "meerprijs", "in overleg mogelijk" — offered, not included. */
const OPTIONAL =
  /garantiepakket|meerprijs[^.\n]{0,80}garantie|garantie[^.\n]{0,60}meerprijs|garantie[^.\n]{0,40}in overleg|optioneel[^.\n]{0,60}garantie/i;

const MENTIONS_WARRANTY = /garantie/i;
const CAMERA = /achteruitrijcamera|parkeercamera|achteruitrij[-\s]?camera|360[°\s]*camera|camera\s+achter/i;
const LEATHER = /leder|leer\b|lederen/i;
const CLOTH = /stoffen bekleding|stof bekleding/i;

export function baselineAnswer(item: Case, criterion: CriterionId): CriterionValue {
  const text = item.description;
  switch (criterion) {
    case "warranty_included": {
      if (!MENTIONS_WARRANTY.test(text)) return "unknown";
      // Order matters: an explicit exclusion is decisive even when the ad also
      // advertises a warranty package further down.
      if (EXCLUDED.test(text)) return "no";
      if (OPTIONAL.test(text) && !INCLUDED.test(text)) return "no";
      if (INCLUDED.test(text)) return "yes";
      return "unknown";
    }
    case "reversing_camera":
      return CAMERA.test(text) ? "yes" : "unknown";
    case "leather_upholstery":
      if (LEATHER.test(text)) return "yes";
      if (CLOTH.test(text)) return "no";
      return "unknown";
  }
}

/**
 * The same three criteria answered from the structured block alone — the
 * "no model at all" option. For camera and upholstery this is the right answer
 * by construction; for warranty it is the flag that `FINDINGS.md` shows is wrong
 * 4 times in 10, which is exactly why it is worth scoring here.
 */
export function structuredAnswer(item: Case, criterion: CriterionId): CriterionValue {
  const s = item.structured;
  switch (criterion) {
    case "warranty_included":
      return s["warrantyExists"] === true ? "yes" : "no";
    case "reversing_camera": {
      const equipment = Array.isArray(s["equipment"]) ? (s["equipment"] as string[]) : [];
      return equipment.some((entry) => /camera/i.test(entry)) ? "yes" : "no";
    }
    case "leather_upholstery": {
      const upholstery = s["upholstery"];
      if (typeof upholstery !== "string" || upholstery === "") return "unknown";
      return /leder/i.test(upholstery) ? "yes" : "no";
    }
  }
}
