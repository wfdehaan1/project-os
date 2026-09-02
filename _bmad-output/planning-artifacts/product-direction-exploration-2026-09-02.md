---
title: "Product Direction Exploration — Research Memory"
status: exploration
created: 2026-09-02
updated: 2026-09-02
inputs:
  - start.md
  - _bmad-output/planning-artifacts/briefs/brief-ProjectOS-2026-07-27/brief.md
  - _bmad-output/planning-artifacts/briefs/brief-ProjectOS-2026-07-27/addendum.md
  - _bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/epics.md
---

# Product Direction Exploration — Research Memory

> **Status: exploration, not commitment.** This records a design conversation held on
> 2026-09-02. Decisions marked **[chosen]** were made explicitly by Wouter during that
> conversation. Decisions marked **[proposed]** are analysis that has not been ratified.
> Nothing here has been through `bmad-product-brief`, `bmad-prd`, or `bmad-architecture`.
>
> It is written to be usable as input to those skills, and it identifies which parts of the
> existing ProjectOS planning artifacts it would supersede if adopted.
>
> **Framing decision [chosen]:** the capability described here belongs *inside* ProjectOS. It is
> not a separate product, a spin-off, or a wedge to be integrated later. See §4.

## 1. What triggered this

`start.md` (a handoff from a separate session) proposed a browser extension that remembers
which cars the user has assessed and re-surfaces that assessment inside marketplace search
results. Read against the existing ProjectOS artifacts, it is not a new product idea — it is a
**missing surface** for a scenario ProjectOS already claims.

The used-car search appears in the brief addendum as founding evidence, and in `epics.md:483`
as a Story 1.5 test fixture. What `start.md` adds is an observation that corrects the problem
model:

> ProjectOS assumes research arrives through AI conversation and pasted text (FR-2).
> In the real car search, research arrived through **browsing**, and increasingly
> **through browsing on a phone**.

That single fact invalidates several premises that were previously coherent together.

## 2. The problem, restated

The activity is a long-running, high-consideration purchase search. It contains two distinct
memory problems that need opposite designs:

| | Durable knowledge | Encounter verdicts |
|---|---|---|
| Example | "V60 T5 only has HUD on Inscription trim" | "listing #4471 — rejected, no reversing camera" |
| Volume | ~20–50 per project | Hundreds |
| Lifetime | Long | Until the listing dies |
| Value density | High | Low individually, high in aggregate |
| Governance | Worth it — rationale, provenance, supersession | Fatal — any friction kills it |
| Interaction | Review and accept | One tap |
| Device | Desk | Phone, in the moment |

ProjectOS is designed entirely for the first and has no answer for the second. `start.md` is
designed entirely for the second and defers the first to "a web app, later." Both are half a
system.

Two pain points reported from the real search:

1. **Lost rationale.** AI accelerates the work so much that the reasoning behind conclusions
   is not retained. This is the ProjectOS thesis.
2. **Re-encounter.** The same and similar cars recur across sites, reposts, and price changes,
   forcing repeated re-derivation of a judgement already made.

## 3. The loop that joins them **[proposed]**

Verdicts flow up into criteria; criteria flow down into screening.

```
Four rejections citing the same reason
        ↓
System proposes a criterion: "Must have: reversing camera"   ← reviewed and accepted
        ↓
Every new listing is pre-screened against the criteria set
        ✓ automatic          (from listing data)
        ✓ reversing camera   (from options list)
        ✗ €27,400            (over ceiling)
        ? towbar             (not stated)
        ↓
User adjudicates only the unknowns
```

This changes what the product is. It is not a notes app that remembers; it is a system that
**does the screening work**, and remembering is how it learns to. It also gives AI a bounded,
checkable job rather than open-ended extraction, and it reconnects the convergent phase
(screening listings) to the divergent phase (narrowing the field), which is the actual arc of
the search.

Two capabilities fall out of the data model at no extra cost:

- **Price-delta on re-encounter.** A rejection with a reason is conditional. Re-encounter is
  exactly when the condition should be re-tested: *"rejected 3 Aug at €25,400 — now €23,900."*
  No crawling or market monitoring required; it is encounter-driven.
- **Variant-level pattern detection.** Rejecting several instances of the same variant for the
  same reason is information about the *variant*, not the listing, and is what actually narrows
  the search field.

## 4. How this lives inside ProjectOS

**[chosen]** This is not a separate product. The research-memory layer becomes part of ProjectOS.
A car search is one project type, not a different app.

### 4.1 The artifact mapping

| Research-memory concept | ProjectOS artifact | New type? |
|---|---|---|
| Criterion — "must have a reversing camera" | **Decision**: governing, supersedable, carries rationale | No |
| Candidate — a car under evaluation | **Candidate** | **Yes** |
| Verdict — interesting / shortlist / rejected + reasons | State on the Candidate | No |
| Listing / offer — price, seller, date, snapshot | **Source Material** with provenance, attached to a Candidate | No |
| Screening finding — "T4 Momentum rarely has a camera" | **Research** | No |
| Criterion proposed from a verdict pattern | **Change Proposal** | No |

Exactly one genuinely new artifact type. Criteria in particular fit Decisions well, including
supersession: *"I dropped the towbar requirement after finding a detachable option."*

### 4.2 Candidates are not a car feature

Every example project in the brief has a candidate-evaluation phase:

- Garden office → which lifting station? (the addendum's own founding scenario)
- Heat pump, solar panels → which unit?
- Holiday → which accommodation?
- Laptop → which model and configuration?

The comparison primitive is generic across ProjectOS's stated domains. What is domain-specific is
the **extraction and matching profile**, not the artifact. That is the same generic-core /
domain-adapter split `start.md` §14 argued for, relocated to the layer that actually varies.

### 4.3 Governance: no new concept required

The two-layer problem in §2 — durable knowledge needs review, high-volume verdicts must not —
resolves against a rule ProjectOS already implies:

> **Review exists to protect Canonical State from AI-authored change.
> User-authored change never needed it.**

- User taps *Rejected — no reversing camera* → user-authored → writes directly. No proposal, no
  queue. Consistent with FR5, which governs *proposals*, not user edits.
- AI screens a listing against criteria → AI-authored → advisory annotation that enters Canonical
  State only when the user acts on it.
- AI notices four rejections share a reason and proposes a criterion → **Change Proposal**,
  reviewed exactly as FR4 and FR5 describe.

The high-volume path does not bypass governance. It was never AI-authored in the first place.

### 4.4 What this does to scope

Adopting this does not shrink ProjectOS. It adds Candidates, identity resolution, share-sheet
capture, on-device extraction, and a second platform to a plan that already carried 18 FRs. The
corrections in §7 still apply and are independent of wanting the full product:

- macOS-only still dies; iOS becomes the primary surface.
- FR-2's pasted-text-only intake still expands to URL capture.
- Epic 3's four adapters still reduce to two.
- Epic 1's `reject` still stands.

The consequence is that the **MVP definition has to shrink somewhere**, which is what §5 addresses.

## 5. Proposed sequencing

The existing epic order is Epic 2 (trusted local project) → Epic 3 (AI conversation) → Epic 4
(re-entry) → Epic 5 (ownership). Under this direction that order is wrong, for one reason:

> **Conversations grounded in a verdict log are the payoff, and the verdict log has to exist
> first.** A conversation with no candidate history is just ChatGPT.

**First shippable slice — Epic 2 with the intake corrected:**

- One Project, created locally, synced across iOS and macOS
- Candidates, criteria (as Decisions), listings as Source Material
- Share-sheet capture and on-device extraction
- Identity resolution: fuzzy match with user confirmation
- Manual verdicts and notes
- Recall on encounter, with price delta
- **No AI at all**

That slice is dogfoodable on a real car search, carries no provider risk, needs no API key, and
retires the hardest unknown — identity — first. It is recognisably ProjectOS: a Project with typed
artifacts and Canonical State. It is not a detour.

Then, in order: conversations grounded in the verdict log → screening and proposals → the
re-entry view → export and deletion. Each layer lands on something already in daily use.

## 6. Decisions taken in this exploration

### 6.1 Surfaces and capture

**D1 — The iOS app is a hard requirement, not a later phase. [chosen, forced]**
Research happens on the phone, in both the AutoScout24/Marktplaats native apps and mobile
Safari. On iOS, share-sheet presence requires an installed app shipping a Share Extension;
there is no web path (Web Share Target is Android-only). The product cannot start as a desktop
browser extension with mobile "later."

**D2 — Recall happens on open, not before the tap. [chosen]**
`start.md` §3 asserts that detecting a duplicate only after opening it is insufficient. That
premise is rejected. It was formed against manual URL re-entry, which is a far worse flow than
share-sheet recall.

Consequence: badge-before-tap is **permanently impossible inside a native marketplace app.**
iOS allows no UI injection into another app, no reading another app's screen, and no third-party
overlay windows. It remains possible in mobile Safari (Safari Web Extension) and on desktop
browsers, so those become enhancements rather than the core.

**D3 — Capture is a share-sheet interaction. [chosen]**
Tap Share → tap the app's extension → a modal recall card renders over the source app → dismiss
returns to the same scroll position. Recall against a known listing ID is a local lookup and is
instant. A *repost* carries a new listing ID and requires extraction before matching, so it
completes a moment later rather than instantly. URL-slug tokens can produce a provisional match
immediately.

**D4 — Extraction runs on-device in a WKWebView. [proposed]**
Assume AutoScout blocks server-side fetches **[chosen assumption]**. The answer is not to fetch
from a server: load the shared URL in an on-device WKWebView — the user's device, IP, cookies,
and a real WebKit engine — and read JSON-LD, `__NEXT_DATA__`, or the DOM. This is the same
request the user's browser would make.

Path asymmetry:

| Shared from | Yields | Extraction |
|---|---|---|
| Safari | Full DOM via the extension's JS preprocessing file | Free, in the extension |
| Native marketplace app | Bare URL | WKWebView pass, ~1–2s, in the host app |

Note: share extensions run under a tight memory limit; the WKWebView pass belongs in the host
app or a background task, not inside the extension.

### 6.2 Identity

**D5 — Fuzzy matching with user confirmation. [chosen]**
The matcher is **recall-biased**: over-suggest and let the user adjudicate. A missed match costs
re-research; a false suggestion costs one tap. Three bands:

- **Exact** (same listing ID, or same plate) — merge silently, show recall.
- **Probable** — ask.
- **Below threshold** — treat as new, retain the comparison for later linking.

The confirmation UI must show **discriminating** evidence, not similarity, because the realistic
false positive is a dealer holding several near-identical cars. Mileage moving slightly forward
is confirming evidence; mileage moving backward indicates a different car or a rolled-back
odometer.

**D6 — Confirmation merges into an item/offer split. [proposed]**
Confirming produces the listing / item / offer separation from `start.md` §7 — derived from a
user action rather than inferred. The assessment attaches to the **car**; listings become a
price-and-seller timeline beneath it. This is what makes the price-delta capability possible.
Denials are equally valuable: a "different car" verdict on a high-scoring pair is training signal
for per-domain feature weights.

**D7 — Identity, not the badge, is the load-bearing feature. [proposed]**
The highest-risk unknown in the entire concept. It needs no product to test.

### 6.3 AI

**D8 — The product hosts conversations. [chosen]**
Chosen over "harvest conclusions from ChatGPT" and over "bounded screening only." The
justification is that a hosted conversation can be **grounded in the user's own verdict log**:
*"of the 12 I shortlisted, which meet the towbar requirement?"*, *"why did I stop looking at T4
Momentums?"* Neither a general chatbot nor a browser extension can answer those.

**D9 — AI is used in exactly two places; everything else is deterministic. [proposed]**

| Job | Frequency | Mechanism |
|---|---|---|
| Extraction | Every listing | Deterministic parsing |
| Fuzzy matching | Every listing | Feature scoring |
| Recall | Every listing | Database lookup |
| **Screening against criteria** | Every new listing | Small model, strict schema |
| **Conversation** | Bursty, per project | Capable model, streaming |

The load-bearing features require no model. This is what keeps cost near zero and what keeps
the product usable with no AI configured at all.

**D10 — Screening must return `unknown`, never infer. [proposed]**
"Reversing camera: not stated" is correct and useful. "Reversing camera: probably yes" is the
failure mode that destroys trust.

**D11 — Retrieval is unnecessary at this scale. [proposed]**
One search is roughly 20 criteria, 40 assessed items, 60 verdicts — the whole project state fits
in a modern context window. `docs/ProjectWorkspace.md` §4 listed "do not send the entire project
to the LLM" as a major technical challenge; it is premature at single-project scale and becomes
real only at multi-project or multi-year scale.

### 6.4 Commercial and provider boundary

**D12 — One-time fee. [chosen]**
Reinforced by the shape of the use case: a purchase search is finite and bursty — weeks of
intense use, then years of nothing. Subscription is structurally mismatched with that pattern
and has churn built in.

**D13 — Never sit between the user and an AI provider. [chosen]**
No inference proxy, ever. The user brings their own API key or runs a local model. Zero variable
cost against a one-time sale.

**D14 — Inference is therefore client-side. [chosen, forced]**
Consequences:

- A browser is a poor place for an API key (no Keychain, XSS-exposed). This weakens any web
  surface that needs inference.
- Local runtimes bind to loopback on the Mac and are unreachable from the phone. Screening on
  the phone therefore requires either a hosted key or deferral to the Mac.

**D15 — Two adapters at MVP, not four. [proposed]**
OpenRouter (one integration, hundreds of models, user pays the provider directly, **OAuth PKCE
connect flow rather than key-pasting**) plus Ollama on the Mac. LM Studio and MLX are variations
on covered ground and can wait.

**D16 — Apple's on-device Foundation Models framework is worth testing for screening. [proposed]**
If a ~3B on-device model handles the screening job reliably, the high-frequency AI work becomes
free, keyless, and available on the phone, and BYOK is needed only for conversations. Requires a
real test — specifically whether it returns `unknown` instead of guessing.

### 6.5 Platform

**D17 — Apple-native, iOS-first, macOS second. [chosen]**
The one-time fee plus the no-middleman constraint plus the phone reality converge on native
Apple. The original macOS-native instinct was correct about *platform*; it was wrong about
*device priority*.

```
iOS app (primary)     share extension · recall · quick assess · capture
                      Safari Web Extension → badges in mobile Safari

macOS app             conversations · criteria · comparison · proposal review
                      browser extension → badges in desktop results
                      local model access (Ollama)

CloudKit              sync · private · zero ops · zero recurring cost

Provider layer        client-side, key in Keychain, user's own account
```

**D18 — Sync is user-owned, via CloudKit. [proposed]**
A one-time fee against a permanent server bill is a structural trap: revenue is a single event,
cost accrues forever and grows with success. CloudKit's private database charges storage against
*the user's* iCloud quota, not the developer's. No backend, no ops, no recurring cost, and it
matches the pricing model exactly.

**D19 — Keep the Android/web door open, but do not build for it. [chosen intent, proposed mechanism]**
Four decisions make a later port a port rather than a rewrite:

1. **CloudKit is a transport, not the data model.** Domain model is plain value types serialized
   to JSON; CloudKit stores opaque payloads plus a few indexed fields.
2. **Sync an append-only operation log**, not mutable rows. Immutable records never conflict, so
   no merge policy or change-token semantics leak upward. *The product already requires this* —
   FR9, FR10, NFR1, NFR2 describe an append-only accepted-change history with a projection. The
   portability is nearly free.
3. **Hard logic stays pure** — matcher, criteria evaluation, normalization as Swift modules with
   no framework dependencies, tested against a fixture corpus. That corpus is language-neutral
   and is the real asset.
4. **Extraction profiles are data, not code** — declarative JSON fetched from a static file.
   Ports for free, *and* fixes DOM churn without an App Store review cycle. Worth doing
   regardless of Android.

A later relay is two endpoints (`POST /ops`, `GET /ops?since=`) over opaque, optionally
client-encrypted blobs. Two transports behind one `SyncPort` is a legitimate end state: Apple-only
users never migrate; cross-platform users get the relay.

Do **not** build an abstraction layer with one implementation now. Make the reversible choices
well; let the second implementation prove the seams when there is a reason for one.

**D20 — A web workspace may be a better second surface than Android. [proposed]**
The same relay unlocks a read-and-organize web surface serving Windows and Linux, and it dodges
the key-in-browser problem entirely provided it does no inference.

## 7. What this supersedes

If adopted, the following existing statements no longer hold:

| Artifact | Statement | Status |
|---|---|---|
| brief.md — MVP exclusions | "Web or mobile applications and cross-device synchronization" | **Superseded.** iOS is the primary surface; sync is required. |
| brief.md — MVP scope | macOS-only, Mac App Store one-time purchase | **Amended.** iOS + macOS, iOS first. Pricing model survives. |
| brief.md / prd.md FR-2 | Source Material limited to pasted text | **Superseded.** URL capture via share sheet with on-device extraction. |
| brief.md — provider direction | Ollama, LM Studio, MLX first-class; OpenRouter optional | **Amended.** OpenRouter primary (OAuth), Ollama on Mac; LM Studio and MLX deferred. |
| ARCHITECTURE-SPINE AD-4, AD-5, AD-6 | Local adapter family, loopback boundaries, native MLX | **Deferred.** Not MVP under this direction. |
| ARCHITECTURE-SPINE AD-2, AD-9 | Capability negotiation, normalized event/error model | **Reduced.** Overkill for two adapters; retain the disclosure parts. |
| epics.md — Epic 3 | Four production adapters | **Reduced** to two. |
| ProjectWorkspace.md §4 | "Do not send an entire project to the LLM" | **Premature** at single-project scale. |

Nothing here revives the Codex App Server path. Epic 1's `reject` stands.

## 8. What survives

More of the existing work applies than expected:

- **Proposal-and-review governance** (FR4, FR5, AD-8, AD-12). Better justified here than in the
  abstract: a criterion proposed from four concrete rejections is a far easier thing to review
  than a Decision extracted from open conversation.
- **AI output visibly distinct from accepted state** (NFR4).
- **Provenance, versioning, supersession** (FR7–FR9) — and the op log makes them structural
  rather than bolted on.
- **Export and ownership** (FR16, NFR3).
- **AD-1** — provider port with owned types, now with two adapters instead of four.
- **AD-8** — owned schema, revalidate every result.
- **AD-12** — only the application mutates state.
- **AD-11** disclosure, reduced to ordinary privacy and cost UX.
- **Local-first**, in modified form: data lives on the user's devices and syncs through the
  user's own iCloud account.

## 9. What is genuinely new

No home in the existing artifacts:

- Encounter verdicts as a distinct high-volume artifact class that bypasses review entirely.
- The listing / item / offer identity split, and fuzzy-match confirmation as a first-class
  interaction.
- The verdict → criteria → screening feedback loop.
- Share-extension capture as the primary intake path.
- Extraction profiles as shipped data.

## 10. Open questions

1. **Does AutoScout24 NL expose the registration plate often enough** to lean on RDW open data
   for enrichment and exact identity? Unverified.
2. **Does the WKWebView extraction path work through cookie-consent overlays** on the target
   sites? JSON-LD and `__NEXT_DATA__` should survive an overlay, but this is untested.
3. **Is Apple's on-device Foundation Models framework strong enough for screening** — specifically,
   does it return `unknown` rather than guessing?
4. **At what point is a re-encounter noticed** — scrolling the results list, or thirty seconds into
   the detail page? If the former, the Safari extension matters far more than assumed and
   share-first capture is weaker than it looks. This is the sharpest open UX question.
5. **Does the share gesture survive real use** at scanning volume, or is it friction that only
   gets paid after the attention it was meant to save is already spent?
6. **How far do matching profiles generalize** beyond cars? Extraction and criteria are genuinely
   generic; the fuzzy-matching feature set is domain-specific and is where genericity actually
   costs something.
7. **BYOK conversion.** Unmeasured, and probably the largest commercial risk.
8. **Name.** ProjectOS remains a placeholder, though this direction makes it a more accurate one
   than a standalone-extension framing would have.

## 11. Risks

- **BYOK is a conversion cliff.** An AI-experienced user will connect an account; an ordinary car
  buyer will not. Mitigated but not solved by the deterministic core working with nothing
  configured, and further mitigated if on-device screening works.
- **Swift is a new language for the builder**, whose stack is React/Next/Node. The app is not
  technically exotic — lists, forms, a webview, a share extension, CloudKit — and the hard parts
  are pure logic that transfers. But it is a real cost against a project that has produced five
  weeks of planning and zero product code.
- **DOM churn** on marketplaces. Mitigated by declarative profiles served as data.
- **Apple-only caps the market**, deliberately, for the first release.
- **Sequencing, not ambition.** Building ProjectOS in full is the stated intent, so scope is not
  itself the risk. The risk is *order*. An 18-FR plan with no dogfoodable slice until late leaves
  the identity design, the capture UX, and the re-encounter hypothesis untested while the
  expensive parts get built. §5 exists to counter this.

## 12. Recommended next steps

Ordered by risk retired per unit of effort. None requires choosing a UI framework.

1. **Matcher spike.** Collect 20–30 real listings actually encountered, ideally including a known
   repost. Design the feature set, scoring function, and three thresholds; measure recall and
   false-positive rate. This is D7, the highest-risk unknown, and it needs no app.
2. **Extraction spike.** Confirm what a real browser engine gets from an AutoScout listing:
   JSON-LD presence, consent-wall behaviour, whether the plate is exposed, and what the native
   app's share payload actually contains.
3. **On-device screening test.** D16. Determines whether BYOK is needed for one feature or two.
4. **Then** run `bmad-prd` in update mode against the existing PRD — not a new brief, since
   ProjectOS remains the product — using this document plus `start.md` as input. Add Candidates
   and capture to the FR set, then re-run `bmad-create-epics-and-stories` for the §5 sequencing.

Answering 1–3 changes what the brief should say. Writing the brief first would encode
assumptions that a week of spike work could settle.
