# Project cover — the pile

**Feature:** every project has a cover at the top of its Overview and on its card in the projects list. It is a vector drawing composed on-device from the project's own record. It grows as the project does. It depicts nothing.

**Status:** design agreed, ready for scoping.
**Prototype:** `pile-cover.html` (hero + list, six states of one record)
**Supersedes:** the generated-cover handoff. Sections 2 (two kinds of cover), 4 (the car example) and 6 (cost and consent) of that document are withdrawn — see §8 below.

---

## 1. The grammar

Six marks. Nothing else may appear on the canvas.

| Mark | Means | Measured by |
|---|---|---|
| **Block** | one settled decision | width = days from raised to settled |
| **Capstone** | a milestone decision | full pile width, laid across the top |
| **Unplaced block** (outlined, tilted, on the ground) | one open question | width = days it has been open |
| **Floating mark** (small dashed square, resting on nothing) | one proposal waiting from Claude | fixed size |
| **Ground line** | the base | — |
| **Pile height** | how much has been settled | emergent, not drawn directly |

The governing rule, and the one that keeps this from becoming wallpaper:

> **Every mark maps to one countable thing. If you cannot point at a shape and name the record it came from, it does not go on the canvas.**

Anything proposed later — texture, shadow, gradient, a second colour, a flourish at the edges — has to name its record or it gets cut.

---

## 2. What the data model needs

One addition. A decision currently knows when it was settled. It also needs **when it was first raised**, because that difference is the block's width and it's the only new fact the cover consumes.

```
Decision {
  raisedAt: date        // NEW — when the project first opened this question
  settledAt: date
  milestone: bool       // NEW — a decision that closes a phase
}
Question {
  askedAt: date
  closedAt: date | null
}
Proposal { createdAt: date, status: pending | accepted | dismissed }
```

**Backfill:** existing decisions have no `raisedAt`. Don't guess it. Render those at the minimum block width and treat "unknown deliberation" as the floor. The pile will fill in properly as new decisions arrive.

**Milestones:** the flag needs a definition or it'll be applied to everything. Proposal: a decision the user explicitly marks as closing a phase, capped at a small number per project. If that's contentious, ship without capstones — the pile works fine without them.

---

## 3. Layout

Deterministic, append-only, no physics engine.

1. Take settled decisions in `settledAt` order.
2. Width = `clamp((settledAt − raisedAt) × scale, minWidth, containerWidth)`.
3. First-fit: walk courses bottom-up, place in the first course with room. If none, start a new course.
4. Capstone, if any, spans the container at the top.
5. Open questions lie on the ground to the right of the pile, left to right in `askedAt` order, each with a small fixed tilt from a repeating sequence — deterministic, not random.
6. Proposals float above the pile's top edge, centred.

**Stability is a hard requirement.** A block that has been placed must never move. This is what makes a project recognisable by its cover between visits, and it's the reason first-fit was chosen over any packing algorithm that optimises. Recomputation from the same ordered record must produce identical output — so placement doesn't need persisting, but any edit to a historical `raisedAt` will reflow the pile. Editing settled decisions should be rare; if it isn't, revisit this.

**All sizes derive from canvas width**, so the hero and the 136px-tall list thumbnail run through the same function with no special-casing.

---

## 4. Overflow

At roughly seven courses the pile reaches the top of the frame. Rule: once courses exceed the available height, apply a uniform scale to the whole pile to fit. Blocks get smaller together; relative widths and the stacking order are preserved. A long project reads as a big dense pile rather than a clipped one.

Do not clip. Do not scroll. Do not hide old courses.

---

## 5. Colour

Blocks and floating marks: `--acc`. Unplaced blocks and ground: `--ink3`. Background: `--sky`. All inherited from the project's atmosphere, with **no exceptions** — the cover never introduces a colour of its own. (This differs from the earlier generated-cover design, where a known paint colour overrode the theme. That exception dies with that design.)

---

## 6. Text equivalents

The legend under the hero is the cover read back in words, and it must be **generated from the same numbers that drew it**, never hand-written. If the drawing and the legend disagree, the drawing is lying and that's a bug.

The SVG `aria-label` is a full sentence describing the current composition, also generated. Screen reader users get the same information; they do not get a description of an abstract picture.

Empty state: bare ground with unplaced blocks is a legitimate, meaningful cover. There is no "no cover yet" state once a project exists.

---

## 7. Scope

**In:** the drawing engine, the `raisedAt` and `milestone` fields, the legend generator, hero and thumbnail rendering.

**Out:** image models, prompts, generation cost, spend caps, consent flows, network calls of any kind. The pile is composed locally from data the app already holds. Nothing leaves the machine, so *Saved on this Mac* stays true and the whole consent apparatus from the previous handoff is unnecessary.

**Also out:** letting users choose a different grammar per project. Atmosphere picks colour and that is the right amount of personalisation. If projects speak different visual languages the list stops being comparable.

---

## 8. What changed from the previous handoff, and why

The earlier design depicted the project's subject — a car that got more specific as the shortlist narrowed. It was appealing and it was expensive in every sense: an image model, a per-image charge, a spend cap, a consent screen, a privacy exception, and a class of failure where the cover renders more certainty than the project actually has.

The pile gets most of the same value — a cover that means something and changes as the work does — for none of that. It is free, instant, offline, deterministic, and cannot be factually wrong, because it never claims a fact about the world.

What we gave up: the delight of seeing your actual car appear. That's real, and it's why the "use your own photo" escape hatch stays.

---

## 9. Acceptance criteria

- [ ] Same record renders identically on every load
- [ ] Adding a decision changes only the new block's neighbourhood; no existing block moves
- [ ] A project with zero decisions renders bare ground plus its open questions
- [ ] A project with 40 decisions fits the frame
- [ ] Hero and thumbnail are the same function, different canvas
- [ ] Legend counts match the marks on the canvas, always
- [ ] Cover recolours correctly across all five atmospheres, including dark
- [ ] `aria-label` describes the actual composition
- [ ] No network request is made to render a cover

---

## 10. Open questions

1. **Reversals.** A decision that was settled and then overturned is the most expressive fact we aren't spending. A block that gets cut back, or scarred. Worth a follow-up spike — but only if the record actually tracks reversals today.
2. **Absence.** The spine version could show a stretch where nobody opened the project. The pile can't, and I'd rather leave the gap than invent a decorative mark for it. If it matters, it wants a separate ground layer, not a change to this grammar.
3. **Who drove it.** Decisions made by the user versus accepted from Claude could be two weights of the same block. Quietly answers "am I running this or is it running itself." Needs a design pass before it's specced.
4. **Milestone definition** — see §2.
5. **Where else the cover appears.** Share view? Export? Print? Each implies an aspect ratio, and the answer should be settled before the engine hardens.
