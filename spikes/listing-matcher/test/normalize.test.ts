import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  fold, jaccard, monthsBetween, normalizePlate, sameText, sellerKey, trimTokens,
} from "../src/normalize.ts";

describe("normalizePlate", () => {
  it("strips punctuation and upper-cases", () => {
    assert.equal(normalizePlate("k-693-ks"), "K693KS");
  });

  it("treats an unpunctuated plate as the same key", () => {
    assert.equal(normalizePlate("HZV11j"), normalizePlate("hzv-11-J"));
  });

  it("rejects anything that is not six characters, so a capture artefact cannot merge two cars", () => {
    assert.equal(normalizePlate("XX-265"), null);
    assert.equal(normalizePlate("K693KS7"), null);
    assert.equal(normalizePlate(null), null);
  });
});

describe("fold", () => {
  it("removes diacritics and collapses punctuation", () => {
    assert.equal(fold("Citroën  C4 / Grand-Picasso"), "citroen c4 grand picasso");
  });
});

describe("trimTokens", () => {
  it("drops the words every listing in the segment carries", () => {
    const tokens = trimTokens("2.0 B3 Momentum Advantage | Automaat | Benzine | NAP");
    assert.ok(tokens.has("momentum"));
    assert.ok(tokens.has("advantage"));
    assert.ok(!tokens.has("automaat"), "automaat is a stopword");
    assert.ok(!tokens.has("benzine"), "benzine is a stopword");
    assert.ok(!tokens.has("nap"), "nap is a stopword");
  });

  it("drops single characters, which are punctuation debris rather than tokens", () => {
    assert.ok(!trimTokens("T5 | R Design").has("r"));
  });
});

describe("jaccard", () => {
  it("is 1 for identical sets and 0 for disjoint ones", () => {
    assert.equal(jaccard(new Set(["a", "b"]), new Set(["a", "b"])), 1);
    assert.equal(jaccard(new Set(["a"]), new Set(["b"])), 0);
  });

  it("returns null rather than 0 when a side is empty — that is unknown, not disagreement", () => {
    assert.equal(jaccard(new Set(), new Set(["a"])), null);
  });
});

describe("sellerKey", () => {
  it("collapses branches of one dealer chain onto the same key", () => {
    assert.equal(
      sellerKey("Autobedrijf Jacob Schaap Emmeloord B.V."),
      sellerKey("Autobedrijf Jacob Schaap Heerenveen"),
    );
  });

  it("keeps unrelated dealers apart", () => {
    assert.notEqual(sellerKey("Baauw Automotive"), sellerKey("Merkbus BV"));
  });
});

describe("sameText / monthsBetween", () => {
  it("reports unknown when either side is missing", () => {
    assert.equal(sameText(null, "Grijs"), null);
    assert.equal(monthsBetween("2020-01-01", null), null);
  });

  it("counts whole months across a year boundary", () => {
    assert.equal(monthsBetween("2019-11-01", "2020-02-01"), 3);
  });
});
