import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { match } from "../src/score.ts";
import type { Listing } from "../src/types.ts";

/** A real corpus row, used as the base for every case below. */
const base: Listing = {
  id: "base",
  site: "autoscout24.nl",
  listingId: "f029e35f-9ba6-4dc7-84f9-ed0f7ddf4df3",
  capturedAt: "2026-09-02T14:54:31.594Z",
  plate: "J-056-VK",
  make: "Volvo",
  model: "V60",
  variant: "V60",
  trim: "2.0 B3 Momentum Advantage | Achteropkomend verkeer",
  body: "Stationwagen",
  firstRegistration: "2020-03-01",
  mileageKm: 129_720,
  priceEur: 22_950,
  fuel: "Benzine",
  transmission: "Automatisch",
  powerHp: 163,
  color: "Grijs",
  upholstery: "Leder",
  doors: 5,
  sellerName: "Henk Scholten Heerlen B.V.",
  sellerCity: "HEERLEN",
};

const listing = (overrides: Partial<Listing>): Listing => ({ ...base, ...overrides });

describe("hard keys", () => {
  it("merges on the same listing id from the same site", () => {
    const result = match(base, listing({ id: "b", plate: null }));
    assert.equal(result.band, "exact");
    assert.equal(result.hardKey, "listingId");
  });

  it("does not merge on the same id string from a different site", () => {
    const other = listing({ id: "b", site: "autotrack.nl", plate: null });
    assert.notEqual(match(base, other).hardKey, "listingId");
  });

  it("merges on the plate across sites, regardless of how it is punctuated", () => {
    const other = listing({
      id: "b", site: "autotrack.nl", listingId: "59524285", plate: "j056vk",
    });
    const result = match(base, other);
    assert.equal(result.band, "exact");
    assert.equal(result.hardKey, "plate");
  });
});

describe("vetoes", () => {
  it("rejects two known, different plates outright", () => {
    const other = listing({ id: "b", listingId: "other", plate: "K-467-ST" });
    const result = match(base, other);
    assert.equal(result.band, "different");
    assert.ok(result.vetoes.some((veto) => veto.feature === "plate"));
  });

  it("rejects a backwards odometer even when everything else agrees", () => {
    const rolledBack = listing({
      id: "b", listingId: "other", plate: null,
      capturedAt: "2026-12-02T00:00:00.000Z",
      mileageKm: 99_720,
    });
    const result = match(listing({ plate: null }), rolledBack, { ignoreHardKeys: true });
    assert.equal(result.band, "different");
    assert.ok(result.vetoes.some((veto) => veto.feature === "mileage"));
  });

  it("rejects a different model", () => {
    const other = listing({ id: "b", listingId: "other", plate: null, model: "V90" });
    const result = match(base, other, { ignoreHardKeys: true });
    assert.equal(result.band, "different");
    assert.ok(result.vetoes.some((veto) => veto.feature === "makeModel"));
  });

  it("drops the plate veto along with the plate hard key, so the ablation is honest", () => {
    const other = listing({ id: "b", listingId: "other", plate: "K-467-ST" });
    const result = match(base, other, { ignoreHardKeys: true });
    assert.ok(!result.vetoes.some((veto) => veto.feature === "plate"));
  });
});

describe("scoring", () => {
  it("proposes a relist: months later, odometer forward, price cut, new dealer", () => {
    const relisted = listing({
      id: "b", listingId: "other", plate: null,
      capturedAt: "2026-12-02T00:00:00.000Z",
      mileageKm: 132_960,
      priceEur: 21_900,
      sellerName: "Andere Autohandel B.V.",
      sellerCity: "ELDERS",
    });
    const result = match(listing({ plate: null }), relisted, { ignoreHardKeys: true });
    assert.equal(result.band, "probable");
  });

  it("does not punish a thin record for fields its site never publishes", () => {
    const thin = listing({
      id: "b", site: "autotrack.nl", listingId: "59524285", plate: null,
      firstRegistration: null, powerHp: null, upholstery: null,
      sellerName: null, sellerCity: null, variant: null,
    });
    const result = match(listing({ plate: null }), thin, { ignoreHardKeys: true });
    assert.equal(result.band, "probable");
    // Unknown features must not appear in the denominator at all.
    for (const item of result.evidence) {
      if (item.verdict === "unknown") assert.equal(item.available, 0);
    }
  });

  it("demands more of a same-seller pair, because that is the realistic false positive", () => {
    // Deliberately parked in the penalty band: a pair that clears `probable`
    // from two dealers, and must not clear it from one.
    const start = listing({ plate: null, firstRegistration: null });
    const sibling = (sellerName: string): Listing =>
      listing({
        ...start,
        id: "b",
        listingId: "other",
        capturedAt: "2026-09-06T00:00:00.000Z",
        trim: "2.0 B3 Momentum Advantage | Camera | LED",
        mileageKm: 130_120,
        powerHp: 190,
        upholstery: "Stof",
        sellerName,
      });

    const sameSeller = match(start, sibling(base.sellerName ?? ""), { ignoreHardKeys: true });
    const otherSeller = match(start, sibling("Andere Autohandel B.V."), { ignoreHardKeys: true });

    assert.equal(otherSeller.band, "probable", "two dealers: the same evidence is enough");
    assert.equal(sameSeller.band, "retained", "one dealer: it is not — this is the D5 case");
  });
});

describe("discriminators", () => {
  it("puts an identical odometer on the card but not the shared colour", () => {
    const twin = listing({ id: "b", site: "autotrack.nl", listingId: "59524285", plate: null });
    const result = match(listing({ plate: null }), twin, { ignoreHardKeys: true });
    const features = result.discriminators.map((item) => item.feature);
    assert.ok(features.includes("mileage"), "identical odometer is the discriminating fact");
    assert.ok(!features.includes("color"), "both being grey narrows nothing");
    assert.ok(!features.includes("makeModel"), "both being a Volvo V60 narrows nothing");
  });

  it("surfaces every disagreement, since that is what the user has to adjudicate", () => {
    const other = listing({
      id: "b", listingId: "other", plate: null,
      upholstery: "Stof",
      mileageKm: 129_800,
    });
    const result = match(listing({ plate: null }), other, { ignoreHardKeys: true });
    assert.ok(result.discriminators.some((item) => item.feature === "upholstery"));
  });
});
