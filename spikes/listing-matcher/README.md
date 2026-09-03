# Listing matcher spike (D7)

**Question:** can a hand-written scoring function decide whether two listings are
the same physical car, at a recall high enough to be useful and a false-positive
rate low enough to be tolerable?

D7 calls this the highest-risk unknown in the concept, and it needs no app. Input
is `../listing-corpus`; nothing here touches a network or a UI.

```bash
npm install
npm run validate            # typecheck + tests + evaluation
npm run evaluate -- --sweep --pairs
node --experimental-strip-types src/stress.ts
```

## Answer, in one paragraph

The plate is a hard key on both sites in the corpus (see the corpus's
`FINDINGS.md`), so **the matcher's real job is smaller than D7 assumed**: exact
identity is usually a lookup, and the fuzzy scorer is the fallback for listings
where the plate is absent, withheld, or not yet extracted. In that fallback role
it separates cleanly on this corpus — a margin of 0.42 between the worst true
positive and the best true negative, with the `probable` threshold sitting in the
gap. **But the corpus cannot falsify it**: both positives are same-day cross-site
captures agreeing on plate, odometer *and* price, which is the easiest positive
that can exist. Treat the numbers as "nothing here contradicts D7", not as "D7 is
retired".

## How it decides

Four layers, in order of authority:

1. **Hard keys** — same listing id on the same site, or the same plate. Bands as
   `exact`, merges silently per D5.
2. **Vetoes** — facts no amount of agreement outweighs: two known different
   plates, a different make/model, or an odometer that runs backwards. A
   backwards odometer is never a silent merge; it means a different car or a
   tampered one, and both are things the user must see.
3. **Weighted score** over the features both listings could answer. `unknown` is
   dropped from the denominator rather than counted as disagreement, which is
   what lets a thin JSON-LD-only record match a rich `__NEXT_DATA__` one.
4. **Same-seller adjustment** — a pair from one dealer must clear a higher bar,
   because a dealer holding four near-identical cars is the D5 false positive.

Bands are `exact` / `probable` (ask) / `retained` (treat as new, keep the
comparison for later linking) / `different`.

### Features and weights

| Feature | Weight | Notes |
| --- | ---: | --- |
| `mileage` | 10 | The only directional feature. Identical odometer is the strongest fuzzy signal in the corpus; forward at a plausible rate is confirming; backward is a veto. |
| `firstRegistration` | 8 | Month-exact is a real discriminator. One month apart is *unknown* — sites disagree on registration vs delivery date. |
| `makeModel` | 6 | Heavy, but never a discriminator: everything in one search is the same model. |
| `power` | 5 | Separates B3 / T4 / T5 where the trim line is ambiguous. 2 hp tolerance for kW→hp rounding. |
| `color` | 5 | Cheap, reliably extracted, mismatch near-decisive. |
| `trim` | 4 | Jaccard over tokens, after removing words every listing in the segment carries. |
| `price` | 3 | Weak on purpose — a repost usually exists *because* the price changed. |
| `spec` | 3 | Body, fuel, transmission, doors together. |
| `upholstery` | 3 | Small, but leather vs cloth on one trim level is a different car. |
| `seller` | 2 | Never scores `agree` for a shared seller — see layer 4. |

Weights are hand-set. With two positive pairs there is nothing to learn from;
D6 notes that user confirmations and denials become the training signal later.

### Discriminating evidence, not similarity

D5 requires the confirmation card to show what separates *this* car from a
lookalike. So `MatchResult.discriminators` is not the top-scoring evidence — it
is every disagreement, plus only those agreements a feature explicitly marks as
discriminating. "Both are grey Volvo V60s" never reaches the card. "Both read
129 720 km" does.

## What the evaluation actually shows

`npm run evaluate` runs three scenarios over all 171 pairs. The third is the one
carrying information:

| Scenario | Recall | False positives | Margin |
| --- | --- | --- | --- |
| 1. Hard keys on (ships) | 2/2 | 0/169 | — (plate decided it) |
| 2. Plate and listing id withheld | 2/2 | 0/169 | — (mileage veto decided it) |
| 3. No hard keys, no vetoes — bare score | 2/2 | 0/169 | **0.42** |

The mechanism breakdown under each scenario is the point. In scenario 1 the plate
rejects 151 of 169 negatives; in scenario 2 the mileage veto rejects all 169. The
headline percentages saturate at 100% under almost any settings, so they are the
least useful output here. The margin is the number to read.

Threshold sweep on the bare score: false positives disappear at `probable ≥ 0.60`
and recall never drops across 0.40–0.90. The default 0.62 sits in the gap with
room on both sides. That is a wider operating window than a two-positive corpus
can justify — see the caveat below.

## Stress test

`src/stress.ts` manufactures the case the corpus lacks: each real listing degraded
along one axis and matched against its own original, plate withheld.

| Scenario | Recalled | Worst score |
| --- | --- | --- |
| same day, new ad | 19/19 | 1.00 |
| relist +90d (+3 240 km, −7%, new dealer, trim 70%) | 19/19 | 0.90 |
| relist +365d (+13 140 km, −20%, new dealer, trim 40%) | 19/19 | 0.82 |
| thin extraction (JSON-LD-only site) | 19/19 | 1.00 |
| thin + relist +90d | 19/19 | 0.90 |
| **odometer rolled back** (negative control) | **0/19** | 0.00 |

Worst synthetic positive 0.82 against best *real* negative 0.58 — an operating
margin of 0.24 once reposts are in play, not the 0.42 the corpus alone suggests.

Synthetic positives confirm the generator's assumptions and nothing else. This is
a sensitivity analysis — which feature the score leans on, and how far each axis
moves before recall collapses — not a measured recall rate.

## Caveats, in order of how much they should worry you

1. **Two positives.** Every rate here has a denominator of 2. Nothing about
   recall is measurable at this sample size.
2. **Both positives are the easy case.** Same-day cross-site captures agreeing on
   plate, odometer and price. The corpus still has no repost (same site, new
   listing id) and no price-changed relist.
3. **The hard negatives are easy too.** All 169 are separated by odometer alone,
   because the corpus's captures are same-day and no two different cars share a
   reading. A dealer's two near-identical cars with *close* odometers is the case
   that would hurt, and it is not in the corpus. A probe of that shape scores
   0.92 — it would be proposed.
4. **No same-dealer near-duplicates.** The four `same_variant_diff_car` pairs are
   all cross-dealer, so the same-seller adjustment is exercised only by a unit
   test, never by real data.
5. **No Marktplaats.** Its extraction profile is unknown, and its share payload
   carries no make/model tokens in the URL — the site most likely to need the
   fuzzy path is the one absent from the corpus.

## What would actually retire D7

In descending order of value per unit of effort:

1. Two or three **real reposts** — a dead favourite next to a live relisting of
   the same car. The corpus README already flags these as the highest-value rows.
2. Two or three **same-dealer near-identical pairs** with close odometers. This is
   the only thing that tests the false-positive side honestly.
3. **Marktplaats captures**, to find out whether the fuzzy path has to carry more
   weight there than it does on AutoScout24.

## Porting (D19.3)

`types.ts`, `normalize.ts`, `features.ts` and `score.ts` are pure: no Node import,
no DOM, no `Intl`, no framework type. Every type maps to a Swift struct or enum,
and the feature list is data-shaped so extraction profiles can eventually supply
weights. `corpus.ts`, `evaluate.ts` and `stress.ts` are the harness and do not
port.
