# Listing corpus

Input data for the three spikes in
`_bmad-output/planning-artifacts/product-direction-exploration-2026-09-02.md` §12.

The corpus is the asset, not the code. It is language-neutral (D19.3) and survives
whichever implementation language the matcher ends up in.

## What to collect

**Target: 25-40 listings**, biased toward hard cases rather than volume:

| Must include | Why |
| --- | --- |
| At least 1-2 known reposts (same car, new listing ID) | The positive case the matcher exists for |
| 2-3 near-identical cars from the *same dealer* | The realistic false positive (D5) |
| The same car listed on two sites (AutoScout24 + Marktplaats) | Cross-site identity |
| A spread of your real verdicts, including rejections with reasons | Ground truth for screening (spike 3) and the criteria loop |
| Both sites, roughly proportional to real use | Extraction profile differences |

**Source: your saved/favourited listings** on AutoScout24 and Marktplaats, plus
browser history. This is the real encounter history, which is what makes the
corpus worth anything — but dead listings cannot be re-captured.

Two things to do about that:

- Capture the **favourites list page itself** before working through it. Dead
  entries usually still render make/model/price/thumbnail, which is enough to
  count as a matcher input even without a detail page. Run the snippet on it and
  name the file `favourites-<site>`.
- A dead favourite sitting next to a live near-identical listing *is* the repost
  case. Flag those pairs first — they are the highest-value rows in `pairs.csv`.

If the hard-case quota above cannot be met from favourites alone, top up with a
fresh search on the same criteria.

## How to capture

1. Open the listing detail page in a desktop browser, dismiss the consent wall.
2. Open DevTools console, paste the contents of `capture/capture.js`, hit enter.
3. A JSON bundle downloads. Move it into `raw/`.

The bundle holds the post-hydration DOM, JSON-LD, `__NEXT_DATA__`, og-meta, and
any plate-shaped strings found in the visible text.

Console paste is blocked on some sites — if so, save `capture/capture.js` as a
bookmarklet, or use "Save page as > Webpage, Complete" and drop the `.html` in
`raw/` instead (loses `window.*` state, keeps JSON-LD and the DOM).

**Extra:** for 2-3 listings, capture once in a private window *before* dismissing
the consent wall and suffix the filename `-preconsent`. That answers open
question #2 without needing all 30 captured twice.

## How to annotate

`listings.csv` — one row per capture. `id` matches the raw filename.
`shared_from` is one of `desktop_browser` / `mobile_safari` / `native_app`.
`verdict` is one of `interesting` / `shortlist` / `rejected` / `none`.

`pairs.csv` — **only label the interesting pairs.** Do not enumerate all pairs;
anything not listed is treated as `different`. Relations:

- `same_car` — same physical vehicle (repost, cross-site, price change)
- `same_variant_diff_car` — the hard negative, especially same dealer
- `different` — only worth a row if a naive matcher would plausibly confuse them

## Native app share payloads (spike 2)

Separately, and independent of the corpus: in the AutoScout24 and Marktplaats
iOS apps, share a listing to Notes (and again to Files/Mail — different targets
receive different item types) and paste what comes out into `share-payloads.md`.
We need to know whether the payload is a bare URL, a URL plus title, or
something richer, and whether the URL slug carries identity tokens usable for a
provisional match before extraction completes (D3).

Also capture 2-3 listings from **mobile Safari** using the same snippet via a
bookmarklet, so we can compare what the Safari path yields against the native
path (the asymmetry table in D4).

## Privacy

`raw/` is gitignored — captures contain seller names, phone numbers and
addresses. Annotations in the CSVs should stay free of personal data.

## Status

- Matcher spike implementation: TypeScript, `spikes/listing-matcher/` (D19.3 —
  pure scoring module, no framework deps, ported to Swift later).
- Extraction spike: partly answerable here from `raw/`; the WKWebView half runs
  on the Mac.
- Screening test: Apple Foundation Models, on the Mac.
