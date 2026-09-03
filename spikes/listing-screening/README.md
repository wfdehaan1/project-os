# On-device screening spike (D16)

**Question:** can a ~3B on-device model screen a listing against a criterion
reliably enough to trust — and, per D10, does it return `unknown` instead of
guessing?

The answer decides whether BYOK is needed for one feature or two (D9: screening
runs on every listing, conversation is bursty). If the on-device model handles
screening, the high-frequency AI work becomes free, keyless, and available on the
phone with no key configured at all.

```bash
npm install
npm run baseline          # the floor a model has to beat — runs anywhere
npm run emit              # write fixtures/prompts.jsonl for the Mac runner
npm run mock              # fake responses, to exercise the grading path
npm run grade -- fixtures/responses-mock.jsonl
```

The model call itself needs a Mac — see [Running it](#running-it-on-the-mac).

## Why warranty is the test criterion

It picked itself out of the corpus. From `../listing-corpus/FINDINGS.md`:

- Warranty is the most-cited reason in the user's own verdicts — 11 of 19 rows.
- AutoScout24's structured `warrantyExists` flag disagrees with a careful read of
  the seller's own description on 4 of 10 listings, always by claiming warranty
  where the ad offers it as a paid delivery package.
- The answer lives in Dutch prose that routinely names a 12-month BOVAG warranty
  in the same paragraph that says the asking price excludes it.

That is precisely the job D9 assigns to the small model, and it is not solvable
by reading a field.

Three criteria are scored, chosen to span the difficulty range:

| Criterion | Structurally available | Role |
| --- | --- | --- |
| `warranty_included` | unreliable | The real test. Prose only. |
| `reversing_camera` | yes | Control — the equipment list answers it, so a model that disagrees is inventing. |
| `leather_upholstery` | yes | Floor. If this fails, nothing else matters. |

## Two modes, because abstention is the point

- **`full`** — structured page fields *and* the description. What would ship.
- **`text_only`** — description only. With the structured block withheld, most
  camera and upholstery cases have no stated answer, so a model that keeps
  saying `yes` is inferring from make and model rather than reading. That is the
  D10 failure, made measurable.

Only `warranty_included` is *graded* in `text_only` mode, because only its label
is derived from the prose and therefore still true when the fields are removed.
Grading camera or upholstery there would be scoring against a label the mode
deliberately hides.

## How wrong answers are counted

Never as one accuracy number. The three ways of being wrong have different costs:

| Kind | Meaning | Cost |
| --- | --- | --- |
| **hallucination** | truth is `unknown`, model said yes/no | The D10 failure. Destroys trust. |
| **wrong direction** | truth is yes, model said no | A real mistake, but the evidence quote makes it auditable. |
| **over-abstention** | truth is yes/no, model said `unknown` | The user reads it themselves. Safe. |

A model scoring 70% with zero hallucinations is more useful than one scoring 85%
with six, so the report never sums them.

Two further checks:

- **Schema violations** are recorded separately from wrong answers. A malformed
  response is a prompt-and-decoding problem, often fixable by constrained
  generation; a wrong value is a capability problem and is not. Averaging them
  hides which one you have.
- **Fabricated evidence** — every `yes`/`no` must quote a span that actually
  occurs in what the model was shown. A fluent Dutch sentence that was never in
  the listing is a failure no value-level metric catches.

The schema also rejects an `unknown` that cites evidence (a model arguing itself
out of an answer) and a `yes`/`no` with no citation (unauditable, so unusable).

## The floor: `npm run baseline`

Two no-model options, scored on the same 51 judgements. If the on-device model
does not beat both, D16 is answered without a model.

| | overall correct | warranty correct | hallucinations |
| --- | --- | --- | --- |
| keyword regex over the description | 33/51 (65%) | **9/17** | 3 |
| structured page fields only | 42/51 (82%) | **8/17** | 6 |

The structured baseline's 82% is carried entirely by camera and upholstery (17/17
each — it reads the fields those criteria come from). On warranty it manages 8/17,
and it **cannot abstain**: `warrantyExists` is a boolean, so every listing that
never mentions warranty gets a confident wrong answer. Four of its six
hallucinations are exactly that.

So the bar on warranty is **9/17 with at most 2 hallucinations**. That is a low
bar, and it should be: it is a three-way choice, and a coin weighted to `unknown`
would score 6/17.

## Running it on the Mac

```bash
npm run emit                                    # -> fixtures/prompts.jsonl
cd runner
swift run screen ../fixtures/prompts.jsonl > ../responses-freeform.jsonl
swift run screen --guided ../fixtures/prompts.jsonl > ../responses-guided.jsonl
cd ..
npm run grade -- responses-freeform.jsonl
npm run grade -- responses-guided.jsonl
```

Run **both**. They answer different questions:

- **free-form** — the model is handed the JSON schema in its instructions and
  left to obey it. Violations here are a genuine result: D9 assumes a strict
  schema is cheap, and this is where that assumption gets tested.
- **`--guided`** — generation is constrained to a `@Generable` type, so
  violations are impossible by construction. The interesting comparison is
  whether *value* accuracy also changes. If it does not, the schema question is
  settled and free-form is simply the wrong way to ship it.

`runner/Sources/screen/main.swift` opens a fresh `LanguageModelSession` per
prompt — reusing one would let an earlier listing's reasoning leak into the next
answer, which is a confound rather than a feature. Errors (guardrail refusals,
context overflow) are recorded as responses so the grader counts them instead of
losing them.

**The Swift has never been compiled** — this spike was built on Linux. The shape
is right; check the API names against current Foundation Models documentation
before trusting it.

Worth capturing while you run it: `meta.latency_ms` is in every response. D9 puts
screening on every new listing, so if a listing costs several seconds the feature
needs a different place in the UI than if it costs 300 ms.

## Ground truth, and a caveat about it

`labels.csv` — one row per listing per criterion, with a `provenance` column so
disagreements can be traced rather than argued about:

- `user` — the user's own `verdict_reasons` and the prose agree.
- `text` — read from the seller's description.
- `structured` — from a page field (camera, upholstery).
- `disputed` — **the prose and the recorded verdict conflict.** Three rows.

The disputed rows matter more than their count suggests. Labelling this set
turned up listings where the description says `Standaard (inbegrepen): 12 maanden
BOVAG-garantie` and `verdict_reasons` records "geen garantie inbegrepen". Two more
say `Inbegrepen afleverpakket: Standaard ... BOVAG garantie (12 maanden)` against
a recorded rejection for lack of warranty.

Two consequences:

1. **`verdict_reasons` is not clean ground truth.** The labels here are read from
   the prose, and where that contradicts the recorded verdict the row is marked
   `disputed` rather than silently resolved. Please review those three.
2. **The feature may be worth more than assumed.** If the user misread warranty
   on several listings while skimming, screening is not just automating a tedious
   read — it is catching errors the skim produces. That is a stronger claim than
   the PRD currently makes, and it is worth confirming before writing it down.

The grader prints how the model answered the disputed rows separately. A model
that tracks the prose on those is evidence for the prose.

## Caveats

1. **17 listings, one segment, one site.** Every rate has a denominator of 17,
   and all of it is Dutch Volvo estate ads from AutoScout24. AutoTrack captures
   carry no description, so they cannot pose the question at all.
2. **One criterion is genuinely hard, two are controls.** Do not read the
   overall accuracy figure; read the warranty row.
3. **The labels are one careful reading.** Three are disputed and flagged; the
   rest are mine, from the prose, and reviewable in `labels.csv`.
4. **Prompt phrasing is untuned.** The criterion questions in `criteria.ts` are a
   first draft. If the model underperforms, that is a candidate cause before
   concluding anything about the model.

## Files

| | |
| --- | --- |
| `criteria.ts` | The three criteria and their question text — the experiment's variable |
| `schema.ts` | The D9 strict output contract and its validator |
| `prompt.ts` | Prompt construction, `full` and `text_only` |
| `baseline.ts` | The two no-model floors |
| `grade.ts` | Error taxonomy and reporting — pure |
| `run.ts` | CLI; Node-only |
| `runner/` | Swift, Foundation Models, macOS-only |
| `labels.csv` | Ground truth, reviewable |
| `fixtures/cases.json` | Generated by `../listing-corpus/tools/build_screening_fixtures.py` |
