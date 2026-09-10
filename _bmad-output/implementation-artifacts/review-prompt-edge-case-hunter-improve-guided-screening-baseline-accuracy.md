# Edge Case Hunter review prompt

Invoke the `bmad-review-edge-case-hunter` skill on this diff:

```diff
diff --git a/spikes/listing-screening/README.md b/spikes/listing-screening/README.md
index f829257..0212c8c 100644
--- a/spikes/listing-screening/README.md
+++ b/spikes/listing-screening/README.md
@@ -43,7 +43,11 @@ Three criteria are scored, chosen to span the difficulty range:
 
 ## Two modes, because abstention is the point
 
-- **`full`** — structured page fields *and* the description. What would ship.
+- **`full`** — criterion-relevant structured page fields and the description.
+  Camera receives `equipment`, upholstery receives `upholstery`, and warranty
+  receives no structured field because none reliably proves price inclusion.
+  This prevents identity, price, and unrelated fields from burying the evidence
+  or inviting inference.
 - **`text_only`** — description only. With the structured block withheld, most
   camera and upholstery cases have no stated answer, so a model that keeps
   saying `yes` is inferring from make and model rather than reading. That is the
@@ -74,8 +78,9 @@ Two further checks:
   generation; a wrong value is a capability problem and is not. Averaging them
   hides which one you have.
 - **Fabricated evidence** — every `yes`/`no` must quote a span that actually
-  occurs in what the model was shown. A fluent Dutch sentence that was never in
-  the listing is a failure no value-level metric catches.
+  occurs exactly in the listing fields or seller description. The question and
+  instructions are not valid evidence. A fluent Dutch sentence that was never
+  in the listing is a failure no value-level metric catches.
 
 The schema also rejects an `unknown` that cites evidence (a model arguing itself
 out of an answer) and a `yes`/`no` with no citation (unauditable, so unusable).
@@ -100,29 +105,35 @@ So the bar on warranty is **9/17 with at most 2 hallucinations**. That is a low
 bar, and it should be: it is a three-way choice, and a coin weighted to `unknown`
 would score 6/17.
 
+The grading command is also the acceptance gate: it exits non-zero unless both
+`full` and `text_only` independently meet that warranty bar.
+
 ## Running it on the Mac
 
 ```bash
 npm run emit                                    # -> fixtures/prompts.jsonl
 cd runner
-swift run screen ../fixtures/prompts.jsonl > ../responses-freeform.jsonl
-swift run screen --guided ../fixtures/prompts.jsonl > ../responses-guided.jsonl
+swift run screen ../fixtures/prompts.jsonl > ../responses-freeform-v10.jsonl
+swift run screen --guided ../fixtures/prompts.jsonl > ../responses-guided-v10.jsonl
 cd ..
-npm run grade -- responses-freeform.jsonl
-npm run grade -- responses-guided.jsonl
+npm run grade -- responses-freeform-v10.jsonl
+npm run grade -- responses-guided-v10.jsonl
 ```
 
+Choose an unused suffix for every run; the example starts at `v10` because
+`v5` through `v9` are retained locally as experimental evidence.
+
 Run **both**. They answer different questions:
 
 - **free-form** — the model is handed the JSON schema in its instructions and
   left to obey it. Violations here are a genuine result: D9 assumes a strict
   schema is cheap, and this is where that assumption gets tested.
-- **`--guided`** — generation is constrained to a `@Generable` type, which
-  constrains individual field types but cannot enforce the dependency between
-  `value` and `evidence`. The grader must still reject combinations such as
-  `unknown` with string evidence. This mode also adds guided-only decision
-  instructions, so its result evaluates that complete candidate approach; it
-  does not isolate constrained decoding as the cause of any accuracy change.
+- **`--guided`** — generation chooses a semantic evidence-bearing decision or
+  evidence-free `unknown`. It receives listing evidence without the free-form
+  JSON instructions or criterion question, uses criterion-specific instructions
+  and greedy sampling, then injects the requested criterion and serializes wire
+  JSON with `JSONEncoder`. This evaluates that complete candidate approach; it
+  does not isolate constrained decoding as the cause of an accuracy change.
 
 `runner/Sources/screen/main.swift` opens a fresh `LanguageModelSession` per
 prompt — reusing one would let an earlier listing's reasoning leak into the next
@@ -138,6 +149,31 @@ Worth capturing while you run it: `meta.latency_ms` is in every response. D9 put
 screening on every new listing, so if a listing costs several seconds the feature
 needs a different place in the UI than if it costs 300 ms.
 
+## Latest guided result: value gate accepts, evidence trust rejects
+
+`responses-guided-v9.jsonl` is one untouched live run of all 102 prompts using
+the current runner. It completed with zero runner errors and zero schema
+violations. The warranty result improved from `v5`'s 6/17 (`full`) and 8/17
+(`text_only`) to:
+
+| Mode | Correct | Hallucinations | Wrong direction | Over-abstention | Fabricated warranty quotes |
+| --- | ---: | ---: | ---: | ---: | ---: |
+| `full` | **13/17** | **2** | 0 | 2 | **5** |
+| `text_only` | **13/17** | **2** | 0 | 2 | **5** |
+
+The fixed value gate therefore prints `screening gate: ACCEPT`. Warranty has no
+reliable structured input, so its focused `full` evidence is identical to
+`text_only`; greedy sampling consequently produces the same warranty decisions
+in both modes. The two recorded modes prove fixture completeness, not two
+different warranty contexts.
+
+This is **not a trustworthy or shipping result**. Five warranty answers in each
+mode synthesize wording across lines or remove source markup rather than quoting
+an exact input span. The grader exposes those failures, but the generated schema
+does not structurally prevent them. D16 therefore remains unresolved: value
+classification now clears its floor, while evidence integrity still rejects the
+candidate approach.
+
 ## Ground truth, and a caveat about it
 
 `labels.csv` — one row per listing per criterion, with a `provenance` column so
diff --git a/spikes/listing-screening/runner/Package.swift b/spikes/listing-screening/runner/Package.swift
index 6e27e33..1f47348 100644
--- a/spikes/listing-screening/runner/Package.swift
+++ b/spikes/listing-screening/runner/Package.swift
@@ -1,4 +1,4 @@
-// swift-tools-version: 6.0
+// swift-tools-version: 6.2
 import PackageDescription
 
 // Foundation Models is macOS 26+ / Apple silicon. Building this on an older SDK
diff --git a/spikes/listing-screening/runner/Sources/screen/main.swift b/spikes/listing-screening/runner/Sources/screen/main.swift
index 5863cf0..35e1621 100644
--- a/spikes/listing-screening/runner/Sources/screen/main.swift
+++ b/spikes/listing-screening/runner/Sources/screen/main.swift
@@ -9,9 +9,9 @@
 //   free-form  the model is told the JSON schema in the instructions and left to
 //              obey it. Schema violations here are a real result — D9 assumes a
 //              strict schema is cheap, and this is where that gets tested.
-//   --guided   generation constrains each field to its declared type, but the
-//              generated type cannot enforce the dependency between `value` and
-//              `evidence`. The grader therefore still checks that invariant.
+//   --guided   generation chooses yes(evidence), no(evidence), or evidence-free
+//              unknown. The runner injects the requested criterion and encodes
+//              the resulting wire response as JSON.
 //
 // Foundation Models requires macOS 26+ / Apple silicon. Keep compiling this
 // runner against the current SDK when its API usage or generated shape changes.
@@ -26,6 +26,7 @@ struct Prompt: Codable {
     let criterion: String
     let mode: String
     let system: String
+    let evidence: String
     let user: String
 }
 
@@ -37,42 +38,101 @@ struct RecordedResponse: Codable {
     let meta: [String: String]
 }
 
-/// The guided-generation counterpart of ANSWER_JSON_SCHEMA in src/schema.ts.
-/// Keep the two in step: the grader validates against the TypeScript one.
+/// Guided output makes the value/evidence dependency structural: supported
+/// answers carry evidence, while an abstention cannot carry any. Semantic case
+/// names keep the decision boundary close to the generated schema.
 @Generable
-struct Answer {
+struct QuotedEvidence {
+    @Guide(description: "Copy the shortest decisive exact span from one listing line, preferably 3 to 12 words. Never quote the question, bridge lines, paraphrase, translate, or invent text.")
+    let quote: String
+}
+
+@Generable
+struct CriterionAnswer {
     @Generable
-    enum Value: String {
-        case yes
-        case no
+    enum Decision {
+        case criterionIsPresent(QuotedEvidence)
+        case criterionIsAbsent(QuotedEvidence)
         case unknown
     }
 
-    @Guide(description: "The criterion id exactly as given in the question.")
-    let criterion: String
+    @Guide(description: "Choose criterionIsPresent or criterionIsAbsent only with direct quoted listing evidence; otherwise choose unknown.")
+    let decision: Decision
+}
+
+@Generable
+struct WarrantyAnswer {
+    @Generable
+    enum Decision {
+        case yesIncluded(QuotedEvidence)
+        case noExcludedOrConditional(QuotedEvidence)
+        case unknown
+    }
 
-    @Guide(description: "Classify only after locating decisive listing text. Silence, ambiguity, or a contradiction relevant to the criterion means unknown.")
-    let value: Value
+    @Guide(description: "Choose whether qualifying warranty is included, excluded or conditional, or unresolved according to the session rules.")
+    let decision: Decision
+}
 
-    @Guide(description: "For yes or no, copy a short exact contiguous span from the listing data or seller description that proves the value; never quote the question, paraphrase, translate, combine, or invent text. For unknown, produce Swift nil, never a textual placeholder such as 'null' or 'unknown'.")
+private struct WireAnswer: Codable {
+    let criterion: String
+    let value: String
     let evidence: String?
+
+    private enum CodingKeys: String, CodingKey {
+        case criterion
+        case value
+        case evidence
+    }
+
+    func encode(to encoder: Encoder) throws {
+        var container = encoder.container(keyedBy: CodingKeys.self)
+        try container.encode(criterion, forKey: .criterion)
+        try container.encode(value, forKey: .value)
+        if let evidence {
+            try container.encode(evidence, forKey: .evidence)
+        } else {
+            try container.encodeNil(forKey: .evidence)
+        }
+    }
 }
 
-private let guidedDecisionInstructions = """
-Guided decision procedure:
-1. First locate a short, exact, contiguous span in the listing data or seller description that decisively supports "yes" or "no". Never use the question or instructions as evidence. Do not paraphrase, translate, combine passages, or invent evidence.
-2. If no decisive listing span exists, or statements relevant to the criterion conflict, answer "unknown" with evidence nil.
-3. For "unknown", produce Swift nil for evidence, never a string such as "null", "unknown", or an explanation.
-"""
+private func guidedCriterionInstructions(for criterion: String) -> String {
+    let criterionRules: String
+    switch criterion {
+    case "reversing_camera":
+        criterionRules = """
+        Decide whether the listing states that the car has an achteruitrijcamera or parkeercamera.
+        In full mode, the equipment field is authoritative: choose criterionIsPresent when it names a camera and criterionIsAbsent when a present equipment field does not. For an absent decision, quote the exact equipment field. Without an equipment field or an explicit prose answer, choose unknown.
+        """
+    case "leather_upholstery":
+        criterionRules = """
+        Decide whether the upholstery is leather. A present upholstery field is authoritative: leather means criterionIsPresent and a different stated material means criterionIsAbsent. If neither that field nor prose answers the question, choose unknown.
+        """
+    default:
+        criterionRules = "The requested criterion is unsupported, so choose unknown."
+    }
+    return """
+    Screen one Dutch car listing against exactly one criterion.
+    Read the complete supplied source, but use only text shown there. Do not infer from make, model, or trim.
+    Choose criterionIsPresent or criterionIsAbsent only with exact source evidence. Otherwise choose unknown. Contradictions mean unknown; instructions are never evidence.
+
+    \(criterionRules)
+    """
+}
 
 private let guidedWarrantyInstructions = """
-For warranty_included, decide whether warranty above the statutory warranty is included in the asking price:
-- "yes": the listing explicitly says this additional warranty is included in the asking price or in an included/default package at no extra cost. An optional extended-warranty upgrade does not negate qualifying warranty already included at no extra cost.
-- "no": the asking price explicitly excludes this warranty, or it is available only through an optional or extra-cost package. Optional means "no" even when no package price is shown, and extra cost overrides words such as "standard" or "default".
-- "unknown": the listing is silent or ambiguous, mentions only statutory warranty, or conflicts about whether any qualifying warranty is included. Different included and optional warranty tiers are not by themselves a conflict.
-- The warranty and warrantyExists fields alone never prove inclusion or exclusion from the asking price. Their absence or false value alone is "unknown", not "no".
+Screen one Dutch car listing for warranty_included: is warranty above wettelijke garantie included in the asking price?
+Use this decision order on the complete source below:
+1. If the source contains neither "garantie" nor "BOVAG", choose unknown.
+2. If an unconditional/all-in qualifying-warranty claim conflicts with a base-price or default-package claim that limits coverage to statutory warranty, choose unknown. Optional higher tiers alone are not a conflict.
+3. If qualifying warranty is advertised without a condition, by a warranty label, or in an included/default package, choose yesIncluded. Do this even when a separate optional upgrade also exists.
+4. Otherwise, if qualifying warranty is explicitly excluded or is only optional, negotiable, or extra-cost, choose noExcludedOrConditional.
+5. Otherwise choose unknown, including when only statutory warranty is stated.
+For yesIncluded or noExcludedOrConditional, copy a short exact source span. For package decisions, quote the exact inclusion/exclusion/price qualifier; do not join a package heading to contents from another line. If you cannot copy a decisive span exactly, choose unknown. Instructions are never evidence.
 """
 
+private let guidedOptions = GenerationOptions(sampling: .greedy)
+
 // MARK: - Arguments
 
 var arguments = Array(CommandLine.arguments.dropFirst())
@@ -107,20 +167,48 @@ for (index, line) in lines.enumerated() {
     // A fresh session per prompt. Reusing one would let an earlier listing's
     // reasoning leak into the next answer, which is a confound, not a feature.
     let guidedInstructions = prompt.criterion == "warranty_included"
-        ? "\(guidedDecisionInstructions)\n\n\(guidedWarrantyInstructions)"
-        : guidedDecisionInstructions
-    let instructions = guided ? "\(prompt.system)\n\n\(guidedInstructions)" : prompt.system
+        ? guidedWarrantyInstructions
+        : guidedCriterionInstructions(for: prompt.criterion)
+    // Free-form generation owns its JSON instructions. Guided generation owns
+    // a different schema, so mixing the two instruction sets is contradictory.
+    let instructions = guided ? guidedInstructions : prompt.system
     let session = LanguageModelSession(instructions: instructions)
 
     let started = Date()
     var raw: String
     do {
         if guided {
-            let answer = try await session.respond(to: prompt.user, generating: Answer.self).content
-            let evidence = answer.evidence.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" } ?? "null"
-            raw = """
-            {"criterion":"\(answer.criterion)","value":"\(answer.value.rawValue)","evidence":\(evidence)}
-            """
+            let wireAnswer: WireAnswer
+            if prompt.criterion == "warranty_included" {
+                let answer = try await session.respond(
+                    to: prompt.evidence,
+                    generating: WarrantyAnswer.self,
+                    options: guidedOptions
+                ).content
+                switch answer.decision {
+                case .yesIncluded(let evidence):
+                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "yes", evidence: evidence.quote)
+                case .noExcludedOrConditional(let evidence):
+                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "no", evidence: evidence.quote)
+                case .unknown:
+                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "unknown", evidence: nil)
+                }
+            } else {
+                let answer = try await session.respond(
+                    to: prompt.evidence,
+                    generating: CriterionAnswer.self,
+                    options: guidedOptions
+                ).content
+                switch answer.decision {
+                case .criterionIsPresent(let evidence):
+                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "yes", evidence: evidence.quote)
+                case .criterionIsAbsent(let evidence):
+                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "no", evidence: evidence.quote)
+                case .unknown:
+                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "unknown", evidence: nil)
+                }
+            }
+            raw = String(decoding: try encoder.encode(wireAnswer), as: UTF8.self)
         } else {
             raw = try await session.respond(to: prompt.user).content
         }
@@ -132,15 +220,22 @@ for (index, line) in lines.enumerated() {
     }
 
     let elapsed = Int(Date().timeIntervalSince(started) * 1000)
+    var metadata = [
+        "runner": guided ? "foundation-models-guided" : "foundation-models-freeform",
+        "latency_ms": String(elapsed),
+    ]
+    if guided {
+        metadata["sampling"] = "greedy"
+        metadata["guided_contract"] = prompt.criterion == "warranty_included"
+            ? "warranty-evidence-only-greedy"
+            : "criterion-focused-greedy"
+    }
     let record = RecordedResponse(
         id: prompt.id,
         criterion: prompt.criterion,
         mode: prompt.mode,
         raw: raw,
-        meta: [
-            "runner": guided ? "foundation-models-guided" : "foundation-models-freeform",
-            "latency_ms": String(elapsed),
-        ]
+        meta: metadata
     )
     print(String(decoding: try encoder.encode(record), as: UTF8.self))
 
diff --git a/spikes/listing-screening/src/grade.ts b/spikes/listing-screening/src/grade.ts
index bd0ae2e..87f1962 100644
--- a/spikes/listing-screening/src/grade.ts
+++ b/spikes/listing-screening/src/grade.ts
@@ -59,14 +59,11 @@ export interface Report {
  */
 export function evidenceIsFabricated(evidence: string | null, shown: string): boolean {
   if (evidence === null) return false;
-  const needle = normalize(evidence);
-  if (needle.length < 8) return false; // too short to judge
-  return !normalize(shown).includes(needle);
+  const exactEvidence = evidence.trim();
+  if (exactEvidence === "") return true;
+  return !shown.includes(exactEvidence);
 }
 
-const normalize = (value: string): string =>
-  value.toLowerCase().replace(/\s+/g, " ").replace(/[^\p{L}\p{N} ]/gu, "").trim();
-
 export function summarize(label: string, judgements: readonly Judgement[]): Report {
   const count = (kind: ErrorKind): number =>
     judgements.filter((judgement) => judgement.kind === kind).length;
@@ -83,6 +80,28 @@ export function summarize(label: string, judgements: readonly Judgement[]): Repo
   };
 }
 
+export interface WarrantyGate {
+  readonly passes: boolean;
+  readonly correct: number;
+  readonly hallucinations: number;
+}
+
+/** Shipping bar from the spike README; both prompt modes must meet it independently. */
+export function evaluateWarrantyGate(report: Report): WarrantyGate {
+  const warranty = report.judgements.filter(
+    (judgement) => judgement.criterion === "warranty_included",
+  );
+  const correct = warranty.filter((judgement) => judgement.kind === "correct").length;
+  const hallucinations = warranty.filter(
+    (judgement) => judgement.kind === "hallucination",
+  ).length;
+  return {
+    passes: warranty.length === 17 && correct >= 9 && hallucinations <= 2,
+    correct,
+    hallucinations,
+  };
+}
+
 /** Grade a deterministic answerer — the baselines, and anything else without a model. */
 export function gradeAnswerer(
   label: string,
diff --git a/spikes/listing-screening/src/prompt.ts b/spikes/listing-screening/src/prompt.ts
index 53674a5..cda8f39 100644
--- a/spikes/listing-screening/src/prompt.ts
+++ b/spikes/listing-screening/src/prompt.ts
@@ -29,40 +29,54 @@ ${JSON.stringify(ANSWER_JSON_SCHEMA, null, 2)}
 "evidence" must be a verbatim quote from the listing, and must be null when the value is "unknown".
 When in doubt, answer "unknown". An honest "unknown" is more useful than a confident guess.`;
 
-/** The structured facts worth showing in `full` mode. Deliberately narrow: dumping every field buries the question. */
-const STRUCTURED_KEYS = [
-  "make", "model", "trim", "firstRegistration", "mileageKm", "priceEur",
-  "upholstery", "warranty", "warrantyExists", "equipment",
-] as const;
+/**
+ * Only show structured fields that can answer the active criterion. Identity,
+ * mileage and price invite inference; unrelated facts bury the evidence in a
+ * small model's context. Warranty inclusion has no reliable structured field.
+ */
+const STRUCTURED_KEYS_BY_CRITERION: Readonly<Record<CriterionId, readonly string[]>> = {
+  warranty_included: [],
+  reversing_camera: ["equipment"],
+  leather_upholstery: ["upholstery"],
+};
 
 export interface Prompt {
   readonly id: string;
   readonly criterion: CriterionId;
   readonly mode: PromptMode;
   readonly system: string;
+  /** Listing content only. Guided generation uses this so the question cannot become evidence. */
+  readonly evidence: string;
   readonly user: string;
 }
 
-export function buildPrompt(item: Case, criterion: CriterionId, mode: PromptMode): Prompt {
-  const definition = CRITERIA_BY_ID.get(criterion);
-  if (definition === undefined) throw new Error(`unknown criterion: ${criterion}`);
-
+/** Input spans that are valid answer evidence. The question is deliberately excluded. */
+export function buildEvidenceSource(item: Case, criterion: CriterionId, mode: PromptMode): string {
   const sections: string[] = [];
 
   if (mode === "full") {
-    const facts = STRUCTURED_KEYS.map((key) => {
+    const facts = STRUCTURED_KEYS_BY_CRITERION[criterion].flatMap((key) => {
       const value = item.structured[key];
-      if (value === undefined || value === null) return `${key}: (niet vermeld)`;
-      if (Array.isArray(value)) return `${key}: ${value.join(", ")}`;
-      return `${key}: ${String(value)}`;
+      if (value === undefined || value === null || value === "") return [];
+      if (Array.isArray(value)) return value.length === 0 ? [] : [`${key}: ${value.join(", ")}`];
+      return [`${key}: ${String(value)}`];
     });
-    sections.push(`GESTRUCTUREERDE GEGEVENS VAN DE PAGINA\n${facts.join("\n")}`);
+    if (facts.length > 0) sections.push(`GESTRUCTUREERDE GEGEVENS VAN DE PAGINA\n${facts.join("\n")}`);
   }
 
   sections.push(`OMSCHRIJVING VAN DE VERKOPER\n${item.description || "(geen omschrijving)"}`);
+  return sections.join("\n\n---\n\n");
+}
+
+export function buildPrompt(item: Case, criterion: CriterionId, mode: PromptMode): Prompt {
+  const definition = CRITERIA_BY_ID.get(criterion);
+  if (definition === undefined) throw new Error(`unknown criterion: ${criterion}`);
+
+  const evidence = buildEvidenceSource(item, criterion, mode);
+  const sections = [evidence];
   sections.push(`VRAAG (criterion id: ${criterion})\n${definition.question}`);
 
-  return { id: item.id, criterion, mode, system: SYSTEM, user: sections.join("\n\n---\n\n") };
+  return { id: item.id, criterion, mode, system: SYSTEM, evidence, user: sections.join("\n\n---\n\n") };
 }
 
 /**
diff --git a/spikes/listing-screening/src/run.ts b/spikes/listing-screening/src/run.ts
index 1bb7c65..206b69c 100644
--- a/spikes/listing-screening/src/run.ts
+++ b/spikes/listing-screening/src/run.ts
@@ -18,10 +18,10 @@ import { baselineAnswer, structuredAnswer } from "./baseline.ts";
 import { loadCases, loadLabels, loadResponses, labelIndex, ROOT } from "./corpus.ts";
 import { CRITERIA } from "./criteria.ts";
 import {
-  classify, evidenceIsFabricated, gradeAnswerer, printByCriterion, printReport, summarize,
+  classify, evidenceIsFabricated, evaluateWarrantyGate, gradeAnswerer, printByCriterion, printReport, summarize,
   type Judgement,
 } from "./grade.ts";
-import { buildAll, buildPrompt } from "./prompt.ts";
+import { buildAll, buildEvidenceSource } from "./prompt.ts";
 import { parseAnswer } from "./schema.ts";
 import type { CriterionId, PromptMode } from "./types.ts";
 
@@ -139,7 +139,7 @@ function grade(path: string): void {
     if (expectation === undefined) continue;
 
     const parsed = parseAnswer(response.raw, response.criterion);
-    const shown = buildPrompt(item, response.criterion, response.mode).user;
+    const shown = buildEvidenceSource(item, response.criterion, response.mode);
     const judgement: Judgement = parsed.ok
       ? {
           id: response.id,
@@ -174,10 +174,17 @@ function grade(path: string): void {
     return;
   }
 
+  const gateByMode = new Map<PromptMode, boolean>();
   for (const [mode, judgements] of byMode) {
     const report = summarize(`model, ${mode} mode`, judgements);
     printReport(report);
     printByCriterion(report, ALL_CRITERIA);
+    const gate = evaluateWarrantyGate(report);
+    gateByMode.set(mode, gate.passes);
+    console.log(
+      `  warranty gate      ${gate.passes ? "PASS" : "FAIL"}   ` +
+      `${gate.correct}/17 correct, ${gate.hallucinations} hallucinations (requires >=9 and <=2)`,
+    );
 
     const notable = judgements.filter(
       (judgement) =>
@@ -206,6 +213,14 @@ function grade(path: string): void {
       console.log(`    ${judgement.id.slice(12, 52).padEnd(42)} expected ${judgement.expected.padEnd(7)} got ${String(judgement.actual)}`);
     }
   }
+
+  const requiredModes: readonly PromptMode[] = ["full", "text_only"];
+  if (!requiredModes.every((mode) => gateByMode.get(mode) === true)) {
+    console.error("\nscreening gate: REJECT — both full and text_only warranty modes must pass");
+    process.exitCode = 1;
+  } else {
+    console.log("\nscreening gate: ACCEPT");
+  }
 }
 
 function main(): void {
diff --git a/spikes/listing-screening/test/grade.test.ts b/spikes/listing-screening/test/grade.test.ts
index 7356530..a5557c1 100644
--- a/spikes/listing-screening/test/grade.test.ts
+++ b/spikes/listing-screening/test/grade.test.ts
@@ -1,8 +1,8 @@
 import assert from "node:assert/strict";
 import { describe, it } from "node:test";
 import { baselineAnswer, structuredAnswer } from "../src/baseline.ts";
-import { classify, evidenceIsFabricated } from "../src/grade.ts";
-import { buildPrompt } from "../src/prompt.ts";
+import { classify, evidenceIsFabricated, evaluateWarrantyGate, summarize, type Judgement } from "../src/grade.ts";
+import { buildEvidenceSource, buildPrompt } from "../src/prompt.ts";
 import type { Case } from "../src/types.ts";
 
 describe("classify", () => {
@@ -22,16 +22,21 @@ describe("classify", () => {
 describe("evidenceIsFabricated", () => {
   const shown = "Deze scherpe meeneemprijs is op basis van levering zonder garantie.";
 
-  it("accepts a quote that differs only in case, spacing and punctuation", () => {
-    assert.equal(evidenceIsFabricated("levering  ZONDER garantie!", shown), false);
+  it("accepts an exact contiguous quote", () => {
+    assert.equal(evidenceIsFabricated("levering zonder garantie", shown), false);
+  });
+
+  it("rejects a normalized paraphrase because evidence must be verbatim", () => {
+    assert.equal(evidenceIsFabricated("levering  ZONDER garantie!", shown), true);
   });
 
   it("flags a fluent sentence that was never in the input", () => {
     assert.equal(evidenceIsFabricated("inclusief 12 maanden BOVAG-garantie", shown), true);
   });
 
-  it("does not judge a quote too short to be distinctive", () => {
+  it("checks short evidence spans too", () => {
     assert.equal(evidenceIsFabricated("garantie", shown), false);
+    assert.equal(evidenceIsFabricated("warranty", shown), true);
   });
 
   it("never flags an abstention", () => {
@@ -87,10 +92,28 @@ describe("prompt modes", () => {
     warranty: "12 maand", warrantyExists: true, upholstery: "Leder", equipment: ["Parkeerhulp met camera"],
   });
 
-  it("full mode shows the structured block", () => {
-    const prompt = buildPrompt(item, "warranty_included", "full");
-    assert.match(prompt.user, /GESTRUCTUREERDE GEGEVENS/);
-    assert.match(prompt.user, /warrantyExists: true/);
+  it("full warranty mode omits every structured field because none proves price inclusion", () => {
+    const full = buildEvidenceSource(item, "warranty_included", "full");
+    const textOnly = buildEvidenceSource(item, "warranty_included", "text_only");
+    assert.equal(full, textOnly);
+    assert.doesNotMatch(full, /GESTRUCTUREERDE GEGEVENS/);
+    assert.doesNotMatch(full, /upholstery:|equipment:|warranty:/);
+    assert.match(full, /Standaard \(inbegrepen\): 12 maanden BOVAG-garantie\./);
+  });
+
+  it("omits missing structured fields instead of presenting absence as negative evidence", () => {
+    const prompt = buildPrompt(listing("Mooie auto.", { upholstery: null }), "leather_upholstery", "full");
+    assert.doesNotMatch(prompt.user, /upholstery:/);
+    assert.doesNotMatch(prompt.user, /niet vermeld/);
+  });
+
+  it("full controls receive only their criterion-relevant structured field", () => {
+    const camera = buildEvidenceSource(item, "reversing_camera", "full");
+    const leather = buildEvidenceSource(item, "leather_upholstery", "full");
+    assert.match(camera, /equipment: Parkeerhulp met camera/);
+    assert.doesNotMatch(camera, /upholstery:|warranty:/);
+    assert.match(leather, /upholstery: Leder/);
+    assert.doesNotMatch(leather, /equipment:|warranty:/);
   });
 
   it("text_only withholds it, which is what turns the criterion into an abstention test", () => {
@@ -105,4 +128,49 @@ describe("prompt modes", () => {
     assert.match(prompt.system, /the answer is "unknown"/);
     assert.match(prompt.user, /criterion id: reversing_camera/);
   });
+
+  it("keeps the criterion question outside the valid evidence source", () => {
+    const item = listing("Mooie auto zonder verdere bijzonderheden.");
+    const prompt = buildPrompt(item, "warranty_included", "text_only");
+    const evidenceSource = buildEvidenceSource(item, "warranty_included", "text_only");
+    assert.equal(prompt.evidence, evidenceSource);
+    assert.match(prompt.user, /bovenop de wettelijke garantie/);
+    assert.doesNotMatch(prompt.evidence, /bovenop de wettelijke garantie/);
+    assert.doesNotMatch(evidenceSource, /bovenop de wettelijke garantie/);
+  });
+});
+
+describe("warranty acceptance gate", () => {
+  const judgement = (kind: Judgement["kind"]): Judgement => ({
+    id: "x",
+    criterion: "warranty_included",
+    expected: kind === "hallucination" ? "unknown" : "yes",
+    actual: kind === "hallucination" ? "no" : "yes",
+    kind,
+    violation: null,
+    evidence: "bewijs",
+    provenance: "text",
+    fabricatedEvidence: false,
+  });
+
+  it("passes only at nine correct answers with at most two hallucinations", () => {
+    const report = summarize("gate", [
+      ...Array.from({ length: 9 }, () => judgement("correct")),
+      ...Array.from({ length: 2 }, () => judgement("hallucination")),
+      ...Array.from({ length: 6 }, () => judgement("over_abstention")),
+    ]);
+    assert.equal(evaluateWarrantyGate(report).passes, true);
+  });
+
+  it("rejects insufficient accuracy, excess hallucinations, or an incomplete mode", () => {
+    const valid = Array.from({ length: 17 }, () => judgement("correct"));
+    assert.equal(evaluateWarrantyGate(summarize("accuracy", [
+      ...valid.slice(0, 8), ...Array.from({ length: 9 }, () => judgement("over_abstention")),
+    ])).passes, false);
+    assert.equal(evaluateWarrantyGate(summarize("safety", [
+      ...valid.slice(0, 9), ...Array.from({ length: 3 }, () => judgement("hallucination")),
+      ...Array.from({ length: 5 }, () => judgement("over_abstention")),
+    ])).passes, false);
+    assert.equal(evaluateWarrantyGate(summarize("incomplete", valid.slice(0, 16))).passes, false);
+  });
 });


diff --git a/_bmad-output/implementation-artifacts/spec-improve-guided-screening-baseline-accuracy.md b/_bmad-output/implementation-artifacts/spec-improve-guided-screening-baseline-accuracy.md
new file mode 100644
--- /dev/null
+++ b/_bmad-output/implementation-artifacts/spec-improve-guided-screening-baseline-accuracy.md
+---
+title: 'Improve guided screening baseline accuracy'
+type: 'bugfix'
+created: '2026-09-03'
+status: 'in-review'
+review_loop_iteration: 0
+baseline_commit: '91749ea87fdfa74b0eab6faa24778f642364e9d4'
+context:
+  - '{project-root}/_bmad-output/planning-artifacts/product-direction-exploration-2026-09-02.md'
+---
+
+<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">
+
+## Intent
+
+**Problem:** `responses-guided-v5.jsonl` is structurally valid but fails the fixed warranty baseline: `full` scores 6/17 correct with zero hallucinations; `text_only` scores 8/17 with one. It over-abstains on explicit warranty language, reverses one paid-package case, and fabricates two citations.
+
+**Approach:** Make guided inference criterion-focused and align its generated cases with the warranty decision boundary. Remove incompatible free-form serialization instructions, exclude distracting fields, use stable sampling, and grade a fresh untouched run against the existing gate.
+
+## Boundaries & Constraints
+
+**Always:** Preserve D10's three-valued contract and D16's fixed bar: both modes independently need at least 9/17 correct warranty answers and at most two hallucinations. Preserve corpus, labels, criterion meanings, verbatim seller text, exact-quote evidence, fresh sessions, and the structural value/evidence invariant. Include only structured fields relevant to the active criterion. Keep live-run provenance and failure diagnostics.
+
+**Ask First:** Changes to labels, corpus, baselines, grading, gate, criterion semantics, generated decisions after inference, or calls-per-criterion. Also ask before treating fabricated evidence as trustworthy.
+
+**Never:** Tune against listing IDs or expected answers; infer from make/model/trim; treat missing fields as negative evidence; overwrite old responses; or use mock output as live proof.
+
+## I/O & Edge-Case Matrix
+
+| Scenario | Input / State | Expected Output / Behavior | Error Handling |
+|----------|--------------|---------------------------|----------------|
+| Included warranty | Delivery claim, included/default package, or warranty label establishes qualifying warranty | `yes` plus exact span | Optional higher tier does not negate included coverage |
+| Excluded/conditional | Price excludes it, or it is only optional, negotiable, or extra-cost | `no` plus exact span | Paid package contents do not imply inclusion |
+| Silent or statutory-only listing | No qualifying warranty statement, or only statutory warranty | `unknown` with no evidence | Missing/false structured fields are not evidence |
+| Conflicting listing | Credible inclusion claims disagree | `unknown` with no evidence | Included plus optional tiers alone are not conflict |
+| Guided serialization | Model returns a semantic decision | Inject criterion and encode valid wire JSON | Record model errors for grading |
+
+</frozen-after-approval>
+
+## Code Map
+
+- `spikes/listing-screening/src/prompt.ts` -- criterion/mode evidence and free-form prompting.
+- `spikes/listing-screening/runner/Sources/screen/main.swift` -- guided generation and serialization.
+- `spikes/listing-screening/src/grade.ts`, `src/run.ts` -- evidence checks and fixed gate.
+- `spikes/listing-screening/test/grade.test.ts` -- prompt/evidence/gate regressions.
+- `spikes/listing-screening/README.md` -- experiment method and interpretation.
+
+## Tasks & Acceptance
+
+**Execution:**
+- [x] `spikes/listing-screening/src/prompt.ts`, `test/grade.test.ts` -- restrict structured evidence to active-criterion fields, omit absence markers, and test that neither unrelated facts nor the question become warranty evidence.
+- [x] `spikes/listing-screening/runner/Sources/screen/main.swift` -- use concise guided-only instructions, semantic cases with structural evidence payloads, and stable sampling; leave free-form behavior unchanged.
+- [x] `spikes/listing-screening/src/grade.ts`, `src/run.ts` -- preserve the fixed gate and exact-evidence boundary; fail closed on incomplete modes.
+- [x] `spikes/listing-screening/README.md` -- document the controlled variable, fresh result, and outcome without rewriting history.
+- [x] `spikes/listing-screening/responses-guided-v9.jsonl` -- run the live guided path and grade untouched local evidence.
+
+**Acceptance Criteria:**
+- Given a guided session, when constructed, then it excludes free-form JSON instructions while its type enforces value/evidence dependency.
+- Given full-mode warranty input, when assembled, then unrelated and unreliable fields are absent and seller text is verbatim.
+- Given the changes, when static checks, tests, build, and whitespace checks run, then all pass.
+- Given a fresh live run, when graded unchanged, then both modes pass 9/17 with at most two hallucinations and no schema violations; fabricated quotes remain visible and block a trust claim.
+
+## Spec Change Log
+
+## Design Notes
+
+Generated cases should express included, excluded/conditional, or unresolved before mapping to wire values. Greedy sampling makes runs comparable; it does not permit retrying until chance produces a pass.
+
+The final untouched `v9` run passes the fixed value gate in both modes at 13/17 correct with two hallucinations, zero wrong-direction answers, two over-abstentions, zero schema violations, and zero runner errors. Five fabricated warranty quotes per mode remain visible, so the result improves value accuracy but does not authorize D16 or a shipping trust claim.
+
+## Verification
+
+**Commands:**
+- `cd spikes/listing-screening && npm run validate` -- expected: all checks and baselines pass.
+- `cd spikes/listing-screening/runner && swift build` -- expected: runner compiles.
+- `cd spikes/listing-screening && npm run emit` -- expected: 102 focused prompts.
+- `cd spikes/listing-screening/runner && swift run screen --guided ../fixtures/prompts.jsonl > ../responses-guided-v9.jsonl` -- observed: 102 live records, no dropped errors.
+- `cd spikes/listing-screening && npm run grade -- responses-guided-v9.jsonl` -- observed: `screening gate: ACCEPT`, no schema violations, five fabricated warranty quotes per mode reported.
+- `git diff --check` -- expected: no whitespace errors.
+
```

