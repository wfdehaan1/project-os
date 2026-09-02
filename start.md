# Product Handoff — Cross-site Research & Decision Assistant

## 1. Context

The user is a frontend software developer with experience in React, Next.js, Node.js and Microsoft Graph. They are exploring whether they want to change careers, but the discussion converged on a more specific insight:

They still enjoy software development, especially when they can:

- investigate a vague or complex problem;
- decide how to solve it;
- build the solution themselves;
- iterate when there is a clear reason;
- retain autonomy over implementation;
- create products around problems they personally experience.

They are less interested in:

- pure product management;
- user research as a primary activity;
- highly technical engineering disciplines such as simulation/mechanics;
- purely hands-on/manual work;
- implementing predefined tickets in someone else's way.

Their preferred direction is therefore closer to an **independent product builder / product engineer**, potentially as a side project first.

---

## 2. Problem That Triggered the Product Idea

The strongest concrete problem came from the user's recent search for a used car.

During a prolonged search, they repeatedly encountered the same cars and had thoughts like:

> “Oh right, what was wrong with this one again?”

or:

> “Why did I like this one?”

The problem is not merely comparing cars.

The deeper problem is:

> **During a long research process, the user loses the context behind previous decisions.**

Relevant information is fragmented across:

- AutoScout24;
- dealer websites;
- marketplaces;
- manufacturer information;
- comparison sites;
- personal notes;
- prior research.

Different sites present the same kind of data differently, making it difficult to maintain a consistent overview.

The user specifically wants to avoid manually re-entering factual data.

---

## 3. Core Product Insight

The product should act as a **personal research layer on top of existing websites**.

It should remember:

- what the user has already seen;
- whether they liked or rejected it;
- why they made that decision;
- what positive/negative points they noted;
- how an item compares with other candidates.

The critical UX insight from the user is:

> It is not enough to notice a duplicate only after manually adding the same URL again.

The user wants to see their prior assessment **directly inside the search results on the source website**.

Example on an AutoScout results page:

```text
Volvo V60 T5 Inscription
€22,950 · 2019 · 118,000 km

⭐ SHORTLIST
+ HUD
+ Panoramic roof
⚠ Transmission maintenance unknown
```

or:

```text
Volvo V60 T4 Momentum
€21,500 · 2020 · 103,000 km

❌ REJECTED
No reversing camera
```

This direct contextual overlay is currently considered the **most important differentiator**.

---

## 4. Product Positioning

Do **not** position the product as:

- another AutoScout;
- another comparison site;
- a car marketplace;
- an AI car-buying chatbot.

A better framing is:

> **Never forget why you did or did not like something you researched online.**

The broader product hypothesis is:

> **Help users remember what they already discovered during complex online purchase research.**

Cars are the first vertical, but the underlying problem also applies to:

- white goods;
- electronics;
- houses;
- heat pumps;
- solar panels;
- laptops;
- holidays;
- other high-consideration purchases.

---

## 5. Important Product Decision: Generic Core, Vertical-specific Enhancements

The user explicitly raised the concern that supporting AutoScout, Bol.com, Coolblue, Funda, etc. could turn the product into a collection of fragile platform integrations.

The proposed architecture should therefore have:

### Generic core

The product understands a generic **Research Item**.

Possible normalized model:

```ts
type ResearchItem = {
  id: string;

  source: {
    domain: string;
    externalId?: string;
    url: string;
  };

  identity: {
    canonicalKey?: string;
    title: string;
    brand?: string;
    model?: string;
    gtin?: string;
    sku?: string;
  };

  offer?: {
    price?: number;
    currency?: string;
    seller?: string;
  };

  metadata: Record<string, unknown>;
};
```

Assessment:

```ts
type Assessment = {
  itemId: string;
  status: "interesting" | "shortlist" | "rejected";

  positives: string[];
  negatives: string[];
  notes?: string;
};
```

### Generic extraction

Attempt to recognize products/items using:

- JSON-LD;
- schema.org (`Product`, `Vehicle`, `Offer`, etc.);
- OpenGraph metadata;
- canonical URL;
- page title;
- visible price;
- image;
- brand/model/product name;
- structured script metadata.

### Optional site adapters

Site-specific adapters should improve reliability and enable richer experiences.

Examples:

```text
adapters/
├── autoscout/
├── bol/
├── coolblue/
├── funda/
└── generic/
```

The product must remain conceptually generic even if the MVP supports only AutoScout.

---

## 6. Three Levels of Support

### Level 1 — Generic detail-page support

Should ideally work on many websites without dedicated integration.

The extension recognizes the main item on a detail page and displays the user's prior assessment.

Example:

```text
⭐ Shortlist
“Good price, but too large.”
```

### Level 2 — Search/list page enrichment

For supported platforms, inject assessment badges directly into result cards.

This is likely to require site-specific DOM adapters.

Example:

```text
Bosch Series 6 washing machine
€749

❌ Rejected
Too deep for available space
```

### Level 3 — Deep vertical integration

For key categories, extract domain-specific facts.

Cars:

- registration plate;
- VIN;
- year;
- mileage;
- engine;
- trim;
- options.

White goods:

- GTIN/EAN;
- capacity;
- dimensions;
- energy label;
- noise level.

Houses:

- address;
- asking price;
- floor area;
- lot size;
- energy label.

---

## 7. Identity / Deduplication Strategy

URL matching alone is too weak.

The product should distinguish:

- listing;
- underlying item/product;
- offer/seller.

Possible generic identity model:

```ts
type Identity = {
  namespace: string;
  value: string;
};
```

Examples:

```ts
[
  { namespace: "gtin", value: "4242005..." },
  { namespace: "mpn", value: "WGG244F5NL" },
];
```

For cars:

- AutoScout listing ID;
- registration plate;
- VIN.

For products:

- GTIN/EAN;
- MPN;
- SKU;
- brand + model.

For houses:

- address;
- postal code + house number.

Long-term, the same underlying item may have multiple offers:

```text
Bosch WGG244F5NL
├── Bol.com       €749
├── Coolblue      €729
└── MediaMarkt    €739
```

The user's assessment should ideally belong to the underlying **item**, while offers remain source-specific.

---

## 8. MVP Direction

Do **not** start by building a large standalone web app.

The recommended first prototype is:

> **A browser extension that remembers which AutoScout cars the user has assessed and shows that assessment directly in AutoScout search results.**

### MVP scope

1. Detect AutoScout search result cards.
2. Extract a stable listing ID / canonical URL.
3. Inject a status badge into the result card.
4. Allow the user to assess an item:
   - interesting;
   - shortlist;
   - rejected.
5. Allow simple notes:
   - positives;
   - negatives;
   - free-text note.
6. Save assessments locally.
7. Restore those assessments every time AutoScout is revisited.
8. Show “already reviewed” state immediately in search results.

Potential extra:

- fade rejected items;
- hide rejected items;
- quick inline assessment from the results page.

### Example UX

```text
Volvo V60 T5
€22,950

Status
[ Interesting ] [ Shortlist ] [ Rejected ]

+ HUD
+ Panoramic roof
- High mileage
```

On later visits:

```text
❌ REJECTED
High mileage
```

The first validation question is:

> **Does the user personally start missing the extension when it is not available?**

That matters more than building a complete research platform up front.

---

## 9. Suggested MVP Architecture

At first, the product can be **extension-only**.

```text
Browser Extension
├── content scripts
├── AutoScout adapter
├── generic item model
├── assessment UI
└── local persistence
```

Use browser storage or IndexedDB initially.

No account is required.

No backend is required.

No web app is required.

This minimizes scope and validates the core interaction.

---

## 10. Later Architecture

Once the concept proves valuable:

```text
Browser Extension
       ↓
      API
       ↓
   Database
       ↓
 Web Research App
```

Suggested conceptual split:

```text
apps/
├── extension/
├── web/
└── api/

packages/
├── core/
├── ui/
├── extraction/
└── adapters/
```

Responsibilities:

### Extension

Primary interaction surface.

- detect what the user is looking at;
- display previous assessments in context;
- capture assessments;
- enrich search result pages.

### Backend

Later.

- sync;
- persistence across devices;
- item identity resolution;
- cross-site matching;
- price history;
- account support.

### Web app

Later.

Research workspace for:

- all saved items;
- research projects;
- comparison;
- criteria;
- shortlist;
- higher-level analysis.

The web app is not the initial core product.

---

## 11. Research Projects

Long-term, users can group items into a research project.

Example:

```text
New family car

Criteria
├── Must: automatic
├── Must: reversing camera
├── Prefer: HUD
├── Prefer: panoramic roof
└── Budget: €18k–€25k

Models
├── Volvo V60
├── Volvo V90
└── Skoda Superb

Concrete listings
├── Listing A
├── Listing B
└── Listing C
```

Potential statuses:

```text
Inbox → Interesting → Shortlist → Rejected
```

`Inbox` is useful because users should be able to save something without immediately evaluating it.

---

## 12. What Should NOT Be in V1

Explicitly avoid:

- own marketplace/search engine;
- crawling all of AutoScout;
- automatic market monitoring;
- full vehicle valuation;
- insurance;
- finance;
- maintenance-history service;
- RDW-like reporting;
- dealer reviews;
- recommendation engine;
- community/social layer;
- large generative-AI chatbot;
- broad support for many platforms.

V1 should remain centered on:

> **See → assess → remember → see the assessment again in context.**

---

## 13. Potential Future Features

Only after validation:

- compare 2–4 items;
- criteria / must-have / nice-to-have;
- cross-site identity matching;
- price change detection;
- offer history;
- duplicate item recognition across sellers;
- AI summary:
  - “Why did I reject this?”
  - “Which items were rejected only because they lacked HUD?”
  - “Which shortlisted items best match my criteria?”
- category-specific extraction;
- automatic model grouping;
- mobile share sheet;
- account + sync.

---

## 14. Key Product Tension

The generic product goal is attractive:

> “Remember your research across the web.”

However, list-page enrichment is not fully generic.

A generic engine can often identify the main product on a detail page using structured metadata, but detecting multiple product cards on a result page usually requires site-specific DOM knowledge.

Therefore:

- **generic core** should be the architecture;
- **site adapters** are an implementation reality;
- adapters should be treated as enhancement modules, not as the conceptual product.

Comparable mental model: password managers are generic products, but still require heuristics and site-specific handling to work well everywhere.

---

## 15. Current Best Next Step

The next agent should **not immediately design the full platform**.

The recommended next step is to define and build the smallest technical spike:

> **AutoScout search result overlay prototype**

Questions to solve:

1. How reliably can AutoScout result cards be detected?
2. Is there a stable listing identifier in the DOM, link or page data?
3. Where can a small badge be inserted without disturbing layout?
4. Can assessments be stored and restored from local extension storage?
5. Can an inline quick-assessment interaction work well?
6. How fragile is the integration to AutoScout DOM changes?
7. What generic abstractions should already exist so AutoScout does not leak through the whole codebase?

The prototype should optimize for learning, not architecture perfection.

---

## 16. Product Principle to Preserve

A useful guiding principle from the discussion:

> **The user should not manually enter factual information that the product can infer.**

User input should primarily be subjective:

- interesting;
- rejected;
- shortlist;
- positive;
- negative;
- note;
- reason for rejection.

Everything factual should be extracted automatically where feasible.

---

## 17. User Preference / Working Style

When continuing this product discussion, keep in mind that the user:

- is technically capable and comfortable with implementation detail;
- prefers building over product research;
- prefers ambiguous problems where they can decide the solution;
- values autonomy;
- is happy to iterate if there is a clear reason;
- wants to start as a side project;
- prefers to build around a problem they personally experience;
- is willing to do the commercial work if needed, but it is not the primary motivator;
- would prefer to keep programming if the product remains small, or sell it and build something new later.

The user generally prefers software-documentation-like explanations with concrete examples.
