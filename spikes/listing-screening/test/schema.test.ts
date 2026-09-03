import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseAnswer } from "../src/schema.ts";

const ok = (raw: string) => {
  const outcome = parseAnswer(raw, "warranty_included");
  assert.ok(outcome.ok, `expected a parse, got: ${outcome.ok ? "" : outcome.violation}`);
  return outcome.answer;
};

const violation = (raw: string): string => {
  const outcome = parseAnswer(raw, "warranty_included");
  assert.ok(!outcome.ok, "expected a schema violation");
  return outcome.violation;
};

describe("parseAnswer: decoding artefacts are tolerated", () => {
  it("accepts a bare object", () => {
    const answer = ok('{"criterion":"warranty_included","value":"no","evidence":"zonder garantie"}');
    assert.equal(answer.value, "no");
  });

  it("accepts a fenced object with prose around it, which small models emit constantly", () => {
    const answer = ok(
      'Here is my answer:\n```json\n{"criterion":"warranty_included","value":"yes","evidence":"12 maanden garantie"}\n```\nHope that helps.',
    );
    assert.equal(answer.value, "yes");
  });

  it("stops at the first balanced object rather than choking on a repeat", () => {
    const answer = ok(
      '{"criterion":"warranty_included","value":"unknown","evidence":null} {"criterion":"warranty_included","value":"yes","evidence":"x"}',
    );
    assert.equal(answer.value, "unknown");
  });

  it("is not confused by braces inside the evidence string", () => {
    const answer = ok('{"criterion":"warranty_included","value":"no","evidence":"pakket {A} zonder garantie"}');
    assert.equal(answer.evidence, "pakket {A} zonder garantie");
  });

  it("treats empty-string evidence as absent", () => {
    assert.equal(ok('{"criterion":"warranty_included","value":"unknown","evidence":""}').evidence, null);
  });
});

describe("parseAnswer: contract breaches are violations, never coerced answers", () => {
  it("rejects a value outside the enum", () => {
    assert.match(violation('{"criterion":"warranty_included","value":"probably","evidence":"x"}'), /outside the enum/);
  });

  it("rejects prose with no JSON at all", () => {
    assert.match(violation("Ja, deze auto heeft 12 maanden garantie."), /no JSON object/);
  });

  it("rejects an answer to a different question", () => {
    assert.match(
      violation('{"criterion":"reversing_camera","value":"yes","evidence":"camera"}'),
      /was asked warranty_included/,
    );
  });

  it("rejects an abstention that cites evidence, because that is a model arguing itself out of an answer", () => {
    assert.match(
      violation('{"criterion":"warranty_included","value":"unknown","evidence":"12 maanden garantie"}'),
      /cited evidence for an 'unknown'/,
    );
  });

  it("rejects a yes/no with no citation, because an unauditable answer is not usable", () => {
    assert.match(
      violation('{"criterion":"warranty_included","value":"yes","evidence":null}'),
      /without citing evidence/,
    );
  });
});
