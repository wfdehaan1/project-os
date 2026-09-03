# Extraction findings

What `raw/` answers on its own, without a WKWebView. Derived by `tools/extract.py`
(output: `extracted.csv`, 19 listing captures — 17 AutoScout24, 2 AutoTrack;
`favorites_autoscout24.json` excluded).

Marktplaats is not represented in `raw/` at all, so nothing below is claimed for it.

## 1. The plate is exposed, on both sites, without scraping visible text

| Site | Where | Coverage |
| --- | --- | --- |
| AutoScout24 | `__NEXT_DATA__` → `listingDetails.vehicle.licensePlate`, also mirrored in `listingDetails.identifier.offerReference` | 16/17 |
| AutoTrack | page `<title>` and `og:title`, as `Volvo V60 Benzine [K-693-KS] \| AutoTrack` | 2/2 |

This settles open question #1 for these two sites, and it changes the matcher's
shape: the strongest identity signal is a hard key, not a fuzzy score.

The `plateCandidates` regex in `capture/capture.js` is the weaker path — it found
13/17 where `__NEXT_DATA__` found 16/17. It misses plates with no dashes (one
listing carries `HZV11j`) and any plate rendered outside `innerText`. Treat it as
a fallback, not the primary.

AutoTrack putting the plate in `og:title` matters for D3: a share payload from
AutoTrack carries the plate before any page is loaded.

## 2. The two ground-truth `same_car` pairs are confirmed mechanically

| AS24 | AutoTrack | plate | mileage | price |
| --- | --- | --- | --- | --- |
| `…bb91a3b0` | `58951006` | K-693-KS | 172 425 km both | € 22 900 both |
| `…f029e35f` | `59524285` | J-056-VK | 129 720 km both | € 22 950 both |

Both cross-site pairs agree on plate, mileage *and* price. They are free wins for
any matcher and therefore prove nothing about the hard cases — the corpus still
has no repost (same site, new listing ID) and no price-changed relist.

## 3. Image URLs are not a cross-listing identity signal

- AutoScout24: `…/listing-images/<listing-uuid>_<image-uuid>.jpg` — namespaced by
  listing, so a repost gets entirely new URLs.
- AutoTrack: `…/<listing-id>/0-<32 hex>.jpg` — the hex looks content-derived, but
  it is still under a listing-scoped path and does not match the AS24 side.

"Same photos" as a matcher feature needs perceptual hashing of the bytes. URL
comparison will never see it.

## 4. The structured warranty flag contradicts the free text — and the verdicts

Warranty is the single most-cited reason in `listings.csv`: 11 of 18 recorded
verdicts turn on it, mostly *"geen garantie inbegrepen en daarmee te duur"*.

AutoScout24 exposes `listingDetails.warranty` (a string like `"12 maand"`, or
null) and `listingDetails.warrantyExists` (a bool). Compared against the manual
reading in `verdict_reasons`, on the 10 AS24 listings judged on warranty:

- **6 agree**
- **4 disagree**, all in the same direction — the structured flag claims warranty
  where the seller's own description offers it only as a paid delivery package
  (`…f029e35f`, `…ff7dc77b`, `…5066ae05`, `…aa4901f2`)

The reverse error exists too: `…980f3fcd` has *"12 MND garantie"* in its own URL
slug and *"inclusief 12 maanden BOVAG-garantie"* in the description, while
`warranty` is null and `warrantyExists` is false.

Two consequences:

1. A rule-based screener over the structured fields would misjudge ~40% of the
   corpus on the criterion the user actually decides by. The decisive fact lives
   in Dutch free-text prose in `description`.
2. That makes warranty the right first test criterion for the on-device screening
   spike (D16) — it is high-frequency, currently unanswerable structurally, and
   has ground truth already recorded in `verdict_reasons`.

`extracted.csv` carries `warranty_field`, `warranty_exists` and `warranty_in_text`
as separate columns so this stays measurable.

## 5. Field availability

Reliable across all 17 AS24 captures: make, model, body, first registration,
mileage (raw int), price (raw int), fuel, transmission, colour, doors, and
seller name / type / city / zip. Power 17/19, upholstery 14/19, previous owners
only 5/19.

AutoTrack's JSON-LD `Car` block is thinner — no first-registration date, no
seller, no power, no upholstery — and it has no `__NEXT_DATA__`, so anything
beyond JSON-LD needs DOM scraping. Extraction profiles will differ per site by
more than a selector table.

## 6. Corpus gaps against the README's targets

| README requirement | Status |
| --- | --- |
| 25–40 listings | 19 |
| 1–2 known reposts (same site, new listing ID) | **0** — the two `same_car` pairs are cross-site, not reposts |
| 2–3 near-identical cars from the *same dealer* | **0** — 4 `same_variant_diff_car` pairs added, all different dealers |
| Same car on two sites | 2 ✓ (AS24 ↔ AutoTrack, not the Marktplaats pairing the README asks for) |
| Spread of verdicts incl. rejections with reasons | ✓ 13 rejected / 5 shortlisted / 1 blank |
| Both sites, roughly proportional | AS24 17, AutoTrack 2, **Marktplaats 0** |
| 2–3 `-preconsent` captures | **0** — open question #2 unanswered |
| 2–3 mobile-Safari captures | **0** — the D4 asymmetry table has no Safari column |
| Native share payloads | ✓ AS24 + Marktplaats, Notes and Files/Mail identical per app |

The nearest same-dealer near-duplicates would come from Autotaalservice Van
Amerongen (3 listings) or the two Broekhuis branches — but those are different
models or different branches, so they are not the D5 false positive.

## 7. Share payloads (from `share-payloads.md`)

- Both apps send **URL + text**, identical to Notes and to Files/Mail.
- AutoScout24's slug carries make, model, trim, fuel and colour, plus the listing
  UUID — enough for a provisional match before extraction, and the payload text
  additionally carries price, mileage and first registration.
- Marktplaats sends a `link.marktplaats.nl/m<id>` shortlink: the numeric listing
  ID is present, but **no** make/model tokens in the URL. The title line carries
  them instead. A provisional match there must parse the title, not the URL.
- Neither payload carries a plate. The plate only arrives after extraction —
  except on AutoTrack, whose `og:title` would carry it.

## Corrections applied to the annotations

- `autotrack_59524285` had an AutoScout24 URL in `listings.csv`; replaced with the
  real one from the capture bundle.
- `…980f3fcd` existed in `raw/` with no `listings.csv` row; row added with the
  verdict left blank.
- `pairs.csv` had no trailing newline and 4 derived `same_variant_diff_car` rows
  were added; the file was rewritten.
- `verdict` values are `Rejected`/`Shortlist`; the README specifies lowercase
  `interesting`/`shortlist`/`rejected`/`none`. Left as-is — flag which spelling wins.
- `.gitignore` contains `.raw`, which ignores nothing; `raw/` is committed despite
  the README's privacy note. `extracted.csv` inherits seller names and cities
  from it.
