# Acceptance and handoff evidence

Run meaningful deterministic tests without network or paid inference by default. Use synthetic fixtures for automated tests; do not copy personal listing captures into product fixtures. Record actual commands and results in the future `apps/ProjectOS/docs/implementation-report.md`. A spec validation result is not an application test result.

## Functional acceptance

| ID / capability | Given | When | Then |
|---|---|---|---|
| AC-01 / CAP-1 | No runtime, key or network | Create/rename two projects, paste labelled English/Dutch text and relaunch | Exact text and separate project data persist; all local operations remain usable. |
| AC-02 / CAP-2 | Missing Ollama, unavailable model, or absent/denied Keychain credential | Configure/test the provider | Show a specific setup/recovery action without losing project work; health success alone is not quality qualification. |
| AC-03 / CAP-2/3 | An off-loopback URL, external redirect or cloud-backed Ollama model | Attempt local configuration/inference | Reject the external path; an offline live test proves the qualified local combination runs locally. |
| AC-04 / CAP-3 | A project with accepted and pending knowledge, sources and older turns | Inspect/narrow context and press Send | Exactly the frozen selected versions and visible range enter the request; pending/history data is excluded unless explicitly selected and labelled. Opening/browsing sends no content. |
| AC-05 / CAP-3 | Long pasted material or an unknown/exceeded context bound | Attempt a request | Store the original intact; block with a narrowing/configuration action instead of silently truncating context. |
| AC-06 / CAP-3 | Stream chunks split mid-UTF8, mid-JSON/SSE event, or combined across events | Receive a response, stop it, or get a mid-stream error | Reassemble correctly; distinguish completed and incomplete output; retain draft/transcript; ignore late chunks and do not auto-retry. |
| AC-07 / CAP-3/5 | A job for project A is active | Navigate to B, change settings, or close/reopen the app | No output reaches B; original configuration is retained; interrupted jobs never replay automatically. |
| AC-08 / CAP-4 | Completed conversation or selected source material | Explicitly choose Suggest project updates | Send one disclosed structured request, create pending typed proposals only, and leave accepted state unchanged. Ordinary chat never secretly triggers this second call. |
| AC-09 / CAP-4 | Malformed/truncated output, extra fields, bad enums, missing target IDs or invalid dependencies | Parse a proposal result | Reject the result before persisting pending proposals; retain chat and show an actionable error. An empty valid proposal list is a successful no-change result. |
| AC-10 / CAP-4/5 | A quote with joined spans, removed markup, translated text, unselected IDs or the wrong source version | Validate evidence | Reject invalid references/quotes. Correct exact Unicode quotes navigate to retained source; AI-authored evidence stays labelled, without claiming semantic truth. |
| AC-11 / CAP-5 | A pending proposal | Accept, edit-and-accept, reject, or defer | Store only explicitly accepted/user-edited content as current; preserve original proposal and review history; rejected/deferred content does not govern. |
| AC-12 / CAP-5 | New proposals with dependent relations | Review and accept the dependency set, or reject/edit a dependency | Apply the entire valid set atomically; invalid dependencies remain blocked with no dangling links or partial changes. |
| AC-13 / CAP-5 | An accepted decision and a replacement on the same subject | Accept replacement, inspect history, then undo | Exactly one governing decision exists after each successful transaction; prior rationale/evidence survives; undo adds history and restores coherent lineage. |
| AC-14 / CAP-4/5/6 | Stale generation snapshots or target revisions, duplicate acceptance or injected store failure | Finish a structured job or apply an update | Stale generated output does not publish pending proposals/fresh guidance. No silent overwrite, double application or partial state; changed dependencies require renewed review and a failed commit reports unsaved state. |
| AC-15 / CAP-5 | Accepted artifacts with relations | Directly correct a task, change status, link records or remove an artifact | Append user-authored history, preserve meaningful relation integrity and support latest-change undo without inference. |
| AC-16 / CAP-6 | Accepted decisions, open work, changes after the previous visit and no network | Open Overview twice within one visit | Show governing/current content and the fixed prior-visit change baseline; evidence/history is inspectable without rereading all chat. |
| AC-17 / CAP-6 | A generated next action citing accepted records | Inspect/dismiss it, then accept a project change | Explain supporting records, dismissal does not mutate project truth, and the saved action is labelled stale after revision change. Invalid references/insufficient evidence cannot become confident guidance. |
| AC-18 / CAP-7 | Sources, transcript, pending/reviewed proposals, accepted versions, relations and return records | Export, verify and restore | Human-readable output and checksums exist; restored root is a separate project with equivalent content and remapped valid references; no secrets are exported. |
| AC-19 / CAP-7 | Corrupt export, unknown schema, bad references or filesystem failure | Export or restore | Report the failure, preserve source data, and publish no partial restored project or apparently successful partial export. |
| AC-20 / CAP-7 | An active job and a project with full history | Confirm permanent project deletion | Offer export first, remove app-managed project content, cancel its jobs and reject late completions; preserve independent credentials/models/exports and make no external-deletion claim. |
| AC-21 / CAP-2/3/7 | OpenRouter usage, rate/billing errors, unsupported schema or network loss | Request generation or inspect diagnostics/export | No secret leakage, hidden spend/retry or fallback; distinguish failure classes when supported by evidence and unknown usage from zero. |
| AC-22 / CAP-8 | A return session and eventual project outcome | Save ratings, time, review effort and outcome, then export | Records remain local and survive relaunch/restore; actual usefulness is supplied by Wouter, never inferred from generated text. |
| AC-23 / CAP-1–8 | A narrow window, keyboard navigation, system dark mode and accessibility inspection | Create a project, converse, inspect evidence and review proposals | Essential actions and state remain discoverable, readable and operable; status is not color-only and panes do not hide pending work irrecoverably. |

## Deterministic proof

- Domain tests: proposal schema/semantic validation, exact quote checking (including Dutch/Unicode and repeated quotes), subject supersession, dependencies, stale acceptance, idempotency and compensating undo.
- Store tests: transaction rollback with injected failure; restart persistence; isolated projects; migration/version rejection; export/restore equivalence and corrupt-archive rejection; deleting a project during a job.
- Transport contract tests using controlled HTTP fixtures: Ollama NDJSON and OpenRouter SSE chunk boundaries, non-success responses, in-stream errors, cancellation, timeout, redirects, routing parameters and credential redaction. Mocks cannot qualify a model.
- Native UI smoke test for create → paste → conversation/proposal view → accept/edit/reject → Overview → relaunch. Automated fake-provider tests must visibly use test configuration, not create a production-ready badge.
- On the intended validation Mac, measure indexed local Overview at p95 ≤2 seconds and artifact/relationship/history reads at p95 ≤500 ms over 30 attempts using a deterministic generated corpus of 1,000 artifacts, 5,000 relationships and 10,000 messages. Record hardware and methodology; these are inherited personal-validation targets, not proven performance.

## Real-provider walkthrough

Run the same scenario once with a recorded locally executing Ollama combination and once with a user-selected OpenRouter model/route. Start with disclosed synthetic text; real project material requires explicit context selection. Wouter supplies the runtime/model and enters the key through the app. Obtain a concrete OpenRouter test spending ceiling before paid calls; respect a provider-side key limit where configured and do not claim an app estimate guarantees billed cost.

1. Create a project and paste: “My garden-office budget is €12,000. I have chosen a wired Ethernet connection. I still need to decide how to handle drainage.”
2. Converse about the open question. The assistant must not claim current web research or engineering verification: this slice has no browsing/tools.
3. Request updates. Review whether the explicit Ethernet commitment and unresolved drainage question were preserved without inventing drainage decisions. Accept/edit/reject through the real UI.
4. Say explicitly: “I have changed my decision: use fibre instead of copper Ethernet because of electrical isolation.” Request and accept a replacement. Confirm that the previous decision and both rationales remain inspectable.
5. Complete a task or resolve an open question through a user action. Quit and reopen; inspect current state and evidence, then export/restore.
6. Stop a real response. Disconnect the local runtime or network as appropriate. Verify draft/state recovery and the absence of fallback.

Record exact adapter/runtime/model/model-format/hardware/configuration; tests and failure paths actually exercised; prompts or disclosed input identifiers; schema/evidence findings; latency; returned usage and known limitations. Do not claim full provider qualification from one happy path or the old listing scores. If a key, runtime or budget is unavailable, mark the corresponding live checks **not run**, identify the exact prerequisite and finish independently verifiable implementation work.

## Usefulness after delivery

The personal trial uses one or two real projects over four to six weeks. The first real return is after at least seven days away. Wouter records whether meaningful work resumes within five minutes, understanding/trust ratings, recommendation outcome and review effort. The existing PRD's directional goals remain: first useful state within 15 minutes excluding provider setup; at least 80% successful returns across at least three returns; understanding/continuation rated at least 4/5; at least 85% material correctness and completeness across three proposal sessions and twenty expected items, with zero omissions that leave governing state materially wrong; at least 70% useful next actions. Record correction, omission and overconfidence separately. No invented minimum review-burden score replaces Q2.

These are owner-test decision aids, not commercial validation or pass conditions an implementation agent can simulate. Severe silent corruption, unrecoverable loss or silent governing-decision replacement stops real use until fixed. Local setup effort should be recorded against the inherited 30-active-minute target, without source edits or undocumented configuration.

## Final handoff from the implementing agent

Deliver the app and exact documented build/run/test commands, provider setup instructions, data location and export/restore instructions, screenshots of the actual native flow, acceptance results, actual live evidence and honest gaps. Distinguish **implemented**, **automatically tested**, **live verified**, and **personally useful**. Do not say the MVP is fully verified when only tests with a fake provider passed. Do not submit to the App Store or claim any unimplemented provider/epic complete.
