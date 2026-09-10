import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { baselineAnswer, structuredAnswer } from "../src/baseline.ts";
import { classify, evidenceIsFabricated, evaluateWarrantyGate, summarize, type Judgement } from "../src/grade.ts";
import { buildEvidenceSource, buildPrompt } from "../src/prompt.ts";
import type { Case } from "../src/types.ts";

describe("classify", () => {
  it("separates the three ways of being wrong, because their costs differ", () => {
    assert.equal(classify("yes", "yes"), "correct");
    assert.equal(classify("unknown", "yes"), "hallucination");
    assert.equal(classify("yes", "no"), "wrong_direction");
    assert.equal(classify("yes", "unknown"), "over_abstention");
  });

  it("counts a guess against a silent listing as a hallucination in both directions", () => {
    assert.equal(classify("unknown", "no"), "hallucination");
    assert.equal(classify("unknown", "yes"), "hallucination");
  });
});

describe("evidenceIsFabricated", () => {
  const shown = "Deze scherpe meeneemprijs is op basis van levering zonder garantie.";

  it("accepts an exact contiguous quote", () => {
    assert.equal(evidenceIsFabricated("levering zonder garantie", shown), false);
  });

  it("rejects a normalized paraphrase because evidence must be verbatim", () => {
    assert.equal(evidenceIsFabricated("levering  ZONDER garantie!", shown), true);
  });

  it("flags a fluent sentence that was never in the input", () => {
    assert.equal(evidenceIsFabricated("inclusief 12 maanden BOVAG-garantie", shown), true);
  });

  it("checks short evidence spans too", () => {
    assert.equal(evidenceIsFabricated("garantie", shown), false);
    assert.equal(evidenceIsFabricated("warranty", shown), true);
  });

  it("never flags an abstention", () => {
    assert.equal(evidenceIsFabricated(null, shown), false);
  });
});

const listing = (description: string, structured: Record<string, unknown> = {}): Case => ({
  id: "x", site: "autoscout24.nl", description, structured,
});

describe("keyword baseline", () => {
  it("lets an explicit exclusion win over a warranty advertised further down", () => {
    const text =
      "Deze scherpe meeneemprijs is op basis van levering zonder garantie.\n" +
      "Wilt u meer zekerheid? Ons afleverpakket bevat BOVAG garantie (12 maanden).";
    assert.equal(baselineAnswer(listing(text), "warranty_included"), "no");
  });

  it("reads an included package as yes", () => {
    assert.equal(
      baselineAnswer(listing("Standaard (inbegrepen): 12 maanden BOVAG-garantie."), "warranty_included"),
      "yes",
    );
  });

  it("abstains when the listing never raises the subject", () => {
    assert.equal(
      baselineAnswer(listing("Mooie auto met trekhaak en cruise control."), "warranty_included"),
      "unknown",
    );
  });
});

describe("structured baseline", () => {
  it("cannot abstain, which is the reason it fails the silent listings", () => {
    const silent = listing("Mooie auto.", { warrantyExists: false });
    assert.equal(structuredAnswer(silent, "warranty_included"), "no");
    assert.equal(classify("unknown", structuredAnswer(silent, "warranty_included")), "hallucination");
  });

  it("reads the equipment list for the camera", () => {
    assert.equal(
      structuredAnswer(listing("", { equipment: ["ABS", "Parkeerhulp met camera"] }), "reversing_camera"),
      "yes",
    );
    assert.equal(structuredAnswer(listing("", { equipment: ["ABS"] }), "reversing_camera"), "no");
  });
});

describe("prompt modes", () => {
  const item = listing("Standaard (inbegrepen): 12 maanden BOVAG-garantie.", {
    warranty: "12 maand", warrantyExists: true, upholstery: "Leder", equipment: ["Parkeerhulp met camera"],
  });

  it("full warranty mode omits every structured field because none proves price inclusion", () => {
    const full = buildEvidenceSource(item, "warranty_included", "full");
    const textOnly = buildEvidenceSource(item, "warranty_included", "text_only");
    assert.equal(full, textOnly);
    assert.doesNotMatch(full, /GESTRUCTUREERDE GEGEVENS/);
    assert.doesNotMatch(full, /upholstery:|equipment:|warranty:/);
    assert.match(full, /Standaard \(inbegrepen\): 12 maanden BOVAG-garantie\./);
  });

  it("omits missing structured fields instead of presenting absence as negative evidence", () => {
    const prompt = buildPrompt(listing("Mooie auto.", { upholstery: null }), "leather_upholstery", "full");
    assert.doesNotMatch(prompt.user, /upholstery:/);
    assert.doesNotMatch(prompt.user, /niet vermeld/);
  });

  it("full controls receive only their criterion-relevant structured field", () => {
    const camera = buildEvidenceSource(item, "reversing_camera", "full");
    const leather = buildEvidenceSource(item, "leather_upholstery", "full");
    assert.match(camera, /equipment: Parkeerhulp met camera/);
    assert.doesNotMatch(camera, /upholstery:|warranty:/);
    assert.match(leather, /upholstery: Leder/);
    assert.doesNotMatch(leather, /equipment:|warranty:/);
  });

  it("text_only withholds it, which is what turns the criterion into an abstention test", () => {
    const prompt = buildPrompt(item, "warranty_included", "text_only");
    assert.doesNotMatch(prompt.user, /GESTRUCTUREERDE GEGEVENS/);
    assert.doesNotMatch(prompt.user, /warrantyExists/);
    assert.match(prompt.user, /12 maanden BOVAG-garantie/);
  });

  it("states the abstention rule and names the criterion it is asking about", () => {
    const prompt = buildPrompt(item, "reversing_camera", "full");
    assert.match(prompt.system, /the answer is "unknown"/);
    assert.match(prompt.user, /criterion id: reversing_camera/);
  });

  it("keeps the criterion question outside the valid evidence source", () => {
    const item = listing("Mooie auto zonder verdere bijzonderheden.");
    const prompt = buildPrompt(item, "warranty_included", "text_only");
    const evidenceSource = buildEvidenceSource(item, "warranty_included", "text_only");
    assert.equal(prompt.evidence, evidenceSource);
    assert.match(prompt.user, /bovenop de wettelijke garantie/);
    assert.doesNotMatch(prompt.evidence, /bovenop de wettelijke garantie/);
    assert.doesNotMatch(evidenceSource, /bovenop de wettelijke garantie/);
  });
});

describe("warranty acceptance gate", () => {
  const judgement = (kind: Judgement["kind"]): Judgement => ({
    id: "x",
    criterion: "warranty_included",
    expected: kind === "hallucination" ? "unknown" : "yes",
    actual: kind === "hallucination" ? "no" : "yes",
    kind,
    violation: null,
    evidence: "bewijs",
    provenance: "text",
    fabricatedEvidence: false,
  });

  it("passes only at nine correct answers with at most two hallucinations", () => {
    const report = summarize("gate", [
      ...Array.from({ length: 9 }, () => judgement("correct")),
      ...Array.from({ length: 2 }, () => judgement("hallucination")),
      ...Array.from({ length: 6 }, () => judgement("over_abstention")),
    ]);
    assert.equal(evaluateWarrantyGate(report).passes, true);
  });

  it("rejects insufficient accuracy, excess hallucinations, or an incomplete mode", () => {
    const valid = Array.from({ length: 17 }, () => judgement("correct"));
    assert.equal(evaluateWarrantyGate(summarize("accuracy", [
      ...valid.slice(0, 8), ...Array.from({ length: 9 }, () => judgement("over_abstention")),
    ])).passes, false);
    assert.equal(evaluateWarrantyGate(summarize("safety", [
      ...valid.slice(0, 9), ...Array.from({ length: 3 }, () => judgement("hallucination")),
      ...Array.from({ length: 5 }, () => judgement("over_abstention")),
    ])).passes, false);
    assert.equal(evaluateWarrantyGate(summarize("incomplete", valid.slice(0, 16))).passes, false);
  });
});
