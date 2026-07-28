# Input Reconciliation: Market Opportunity Research

## Input

- **Source:** `market-projectos-market-opportunity-research-2026-07-27.md`
- **Compared with:** `prd.md` and `addendum.md`
- **Authority rule:** The final product brief, the PRD run memlog, and the user's later decision to define a personal/solo validation build govern wherever the market research recommends a broader concierge or commercial program.
- **Verdict:** The PRD preserves the research's central thesis, competitive caveats, differentiation contracts, and conditional-go posture. Four material market-derived constraints or validation caveats remain under-specified. Commercial validation, provider breadth, distribution, multi-surface access, and broader cohort research are intentional deferrals rather than gaps.

## Material Gaps

### 1. Extraction correctness can pass while consequential state is omitted

**Research signal:** The research treats both accuracy and completeness as primary adoption factors and warns that users need an explicit account of current truth, unresolved work, and decision lineage. It recommends measuring time and corrections required to reach accepted current state.

**Current coverage:** PRD SM-3 measures whether proposed material facts and Decisions are correct before correction. The addendum defines the denominator as all material proposed facts and Decisions. Re-entry notes record whether governing state later proved wrong or missing.

**Gap:** This is principally a precision measure. A model could propose only easy, correct items, omit a consequential Decision, Open Question, dependency, or Task, and still exceed the 85% threshold. Later subjective re-entry notes may reveal the omission, but completeness is not itself a decision gate or counter-metric. That weakens the claim that Canonical State is trustworthy rather than merely non-fabricated.

**Reconciliation recommendation:** Add a lightweight omission/coverage check for each First Useful State and Qualifying Return: identify material accepted-state items present in the source or user's intended project state but absent from the proposal or Re-entry View. Treat repeated consequential omissions as a rethink signal even when SM-3 passes. This need not become a statistically rigorous recall metric for a solo cycle.

### 2. “Materially faster than the incumbent” relies on retrospective judgment rather than an observed baseline

**Research signal:** The strongest diagnostic comparison is a real-project re-entry against the user's actual bundle of chat, notes, files, tasks, and memory. The research explicitly recommends comparison against the actual incumbent workflow rather than a blank control.

**Current coverage:** PRD SM-1 imposes an absolute five-minute target. SM-2 asks the user to rate ProjectOS at least 4/5 and record that it was materially easier than reconstructing with incumbent tools. The addendum asks how the user believes they would have resumed without ProjectOS.

**Gap:** The PRD thesis says re-entry is faster than the incumbent, but the experiment does not observe or establish an incumbent baseline. A five-minute result plus retrospective self-report can show perceived usefulness, but not a credible relative time improvement. The difference matters because the incumbent bundle is the main competitor and already has zero adoption friction.

**Reconciliation recommendation:** Before the validation cycle, record one or more representative incumbent re-entry episodes or a simple baseline estimate based on actual past projects, including elapsed reconstruction time and missed context. Compare Qualifying Returns with that baseline. If an A/B-like comparison would distort a tiny solo study, label the outcome “perceived and absolute re-entry improvement” rather than claiming measured relative speed.

### 3. Persistent-state scope and verified deletion are absent

**Research signal:** The research identifies legible memory scope, correction/deletion, privacy-protective defaults, and verified deletion as trust requirements. It specifically warns that privacy claims exceeding actual behavior are a critical risk.

**Current coverage:** The PRD defines Project scope, Source Material selection, local persistence, correction/undo, transmission disclosure, export, and recovery. It does not claim that local-first eliminates privacy obligations.

**Gap:** No requirement covers deleting a Project or removing retained Source Material, Conversation content, or an Artifact from persistent local state, nor does it define what remains in history, exports, or backups after deletion. Correction and undo do not satisfy deletion semantics. Even for a solo build, real consequential projects may contain sensitive financial, family, contractual, or personal data, so inability to explain and verify removal creates a material trust and privacy blind spot.

**Reconciliation recommendation:** Add observable delete/remove behavior and plain-language retention semantics, including whether accepted history is tombstoned, retained, or permanently erased; ensure exports and provider credentials are unaffected appropriately. Architecture can choose the mechanism, but the product behavior should be specified before testing with sensitive real material.

### 4. BYO-provider cost visibility is weaker than the market risk warrants

**Research signal:** BYO-provider setup is rated a high risk. Recommended mitigation includes guided onboarding, credential validation, cost preview, predictable usage costs, and clear handling of limits. The incumbent bundle is frequently free, so uncertain variable charges can suppress use or distort validation behavior.

**Current coverage:** FR-14 covers API-key validation, rate-limit and insufficient-credit errors, and disclosure that OpenAI bills usage separately. NFR-12 requires honest language about provider cost. The model and cost ceiling remain an open question.

**Gap:** The PRD does not require a cost estimate, usage visibility, or a validation-cycle spending control. Separate-billing disclosure is not the same as making likely or accumulated cost legible. The primary tester could unknowingly avoid substantive use or overspend, either of which would contaminate the continuity test.

**Reconciliation recommendation:** Resolve the model and cost ceiling before implementation, then require at least a pre-use cost expectation and a locally visible cumulative validation estimate or explicit provider-dashboard handoff. Full commercial-grade metering can remain deferred.

## Intentionally Deferred, Not Gaps

| Market-research recommendation or risk | Reconciliation |
| --- | --- |
| Recruit 20–25 participants, emphasize active renovators, run price-bearing asks, and follow with a 50–100-person private beta | Deliberately superseded for this PRD by the user's personal/solo validation decision. The PRD correctly preserves cross-domain positioning and defers claims about switching, payment, and generalizable demand. |
| Validate $39.99 / $59.99 / $79.99, a 14-day evaluation, purchase conversion, App Store packaging, refunds, reviews, and acquisition | Explicitly deferred in PRD §§6–8 and addendum §6. These are commercial gates after the semantic-continuity loop is proven. |
| Support Ollama and prove a provider-neutral adapter | The final brief includes Ollama, but the active validation decision intentionally uses OpenAI first so local-model variance does not confound the continuity test. Addendum §5 preserves the later Ollama quality gate. |
| Mobile capture, hosted sync, sharing, collaboration, professional participation, and portfolio-level retention | Explicitly outside the single-owner Mac validation boundary. Their absence is a known local-first trade-off, not an omission from this experiment. |
| Hero image and project identity | Explicitly deferred as non-essential visual polish for the validation build, while the broader brief retains the decision. |
| Requirements, Risks, Files, Notes, Photos, Purchases, and Measurements as first-class Artifacts | Explicitly excluded by the governing brief and PRD. Their absence may limit particular use cases, but expanding the type system now would test a broader product than authorized. |
| Full migration from provider accounts, broad integrations, and automatic reconstruction of historical conversations | Intentionally narrowed to user-selected paste/file input. This preserves the research constraint to start from real material without accepting the scope and trust risk of bulk reconstruction. |
| Paid-major-version economics, support operations, diagnostics, and compatibility policy | Commercial/operational concerns preserved in the addendum or deferred until product value is proven. They do not determine whether governed continuity works for the builder. |

## Material Research Preserved Correctly

- The opportunity remains explicitly **problem-supported and solution-unvalidated**, warranting focused validation rather than a broad platform commitment.
- The incumbent is correctly framed as the familiar bundle of general AI, notes, files, spreadsheets, tasks, email, and memory—not a single direct competitor.
- The PRD does not rely on generic claims about local storage, BYO AI, project containers, “memory,” or an all-in-one workspace.
- The differentiating loop is intact: selected source or conversation → typed proposal → explicit accept/edit/reject → versioned Canonical State → current-state-first re-entry → explained Next Action.
- Human approval, provenance, rationale, conflict handling, decision supersession, correction, undo, and zero silent state corruption are specified as observable trust contracts.
- Low setup and maintenance burden is measured and protected as a counter-metric rather than optimized through artifact volume or engagement.
- Local ownership, explicit provider transmission, no ProjectOS-hosted content backend, human-inspectable export, and verified recovery are all retained.
- Cross-domain positioning is preserved while allowing the validation projects to be chosen for consequence and fit; the rejected renovation-only definition is not reintroduced.
- The PRD appropriately measures first useful state and successful return after a meaningful gap, and it makes failure on re-entry or disproportionate manual maintenance a rethink/stop condition.

## Final Reconciliation Judgment

No market input requires expanding this personal validation build into the research's larger concierge, beta, pricing, or launch program. The four gaps above are narrower: they improve the validity and trustworthiness of the solo experiment without changing its commitment boundary. Of these, completeness/omission handling and incumbent-baseline clarity most directly affect whether the continuity thesis can be claimed; deletion semantics and cost visibility protect the use of sensitive real material and prevent BYO-provider friction from contaminating the test.
