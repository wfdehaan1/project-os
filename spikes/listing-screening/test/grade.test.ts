import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { baselineAnswer, structuredAnswer } from "../src/baseline.ts";
import { classify, evidenceIsFabricated } from "../src/grade.ts";
import { buildPrompt } from "../src/prompt.ts";
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

  it("accepts a quote that differs only in case, spacing and punctuation", () => {
    assert.equal(evidenceIsFabricated("levering  ZONDER garantie!", shown), false);
  });

  it("flags a fluent sentence that was never in the input", () => {
    assert.equal(evidenceIsFabricated("inclusief 12 maanden BOVAG-garantie", shown), true);
  });

  it("does not judge a quote too short to be distinctive", () => {
    assert.equal(evidenceIsFabricated("garantie", shown), false);
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

  it("full mode shows the structured block", () => {
    const prompt = buildPrompt(item, "warranty_included", "full");
    assert.match(prompt.user, /GESTRUCTUREERDE GEGEVENS/);
    assert.match(prompt.user, /warrantyExists: true/);
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
});
