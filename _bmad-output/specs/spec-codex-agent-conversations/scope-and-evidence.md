# Scope and evidence

## Authority

This is the next feature after commit `4ecf4b2`, not another experiment. The user requested a spec/plan, so this handoff contains no feature implementation. The confirmed target is a **personal-use macOS app with guided Codex setup**. Routine chat must remain inside ProjectOS.

The latest direction explicitly revisits Codex and provider-owned research. It supersedes the older MVP's exclusions of Codex subscription authentication and research tools **only for this feature**. It preserves local ownership, reviewed project changes, explicit provider/context disclosure and existing Ollama/OpenRouter behavior. Historical PRD, architecture, epics and completed experiment records remain unchanged. A future implementation must follow this feature contract for those specific conflicts; it must not revive unrelated deferred scope.

## Source and preservation map

| Source | Load-bearing requirement or observation | Where retained |
|---|---|---|
| Current conversation | Native chat; approved research tools; project changes remain proposals | CAP-2/3/5; experience and permission contract |
| Current conversation | Codex uses built-in tools; SearXNG only for local LLMs | CAP-3/8; provider matrix; AC-05–08 |
| Current conversation | Revisit context preview | CAP-4; turn/history disclosure; AC-09–11 |
| Current conversation | Potential additional providers | CAP-8; small session interface and fake second adapter, no second real integration |
| Confirmed release choice | Personal-use macOS and guided Codex setup | Constraints; P0/P2; AC-01–03 |
| [Experiment report](../../../spikes/codex-acp-chat/REPORT.md) | Live synthetic native streaming/search/proposals/Stop/resume work; runtime packaging and isolation are unproven | P0/P6 gates and acceptance evidence tiers |
| [Completed MVP spec](../spec-projectos/SPEC.md) | Local data, existing conversations, five artifact kinds, exact evidence, atomic acceptance, offline ownership | CAP-5/7/8; persistence and acceptance contracts |
| Current app source at baseline | Provider selection is global; conversations lack backend/session binding; SQLite migration is v3; exports have identity remapping | P1 migration and P5 export/restore work |
| Experiment lifecycle review | Buffer overflow, stale callbacks, partial failure output, duplicate windows, corrupt state and replay loss matter | Session ownership, durable journal and AC-12–18 |

These sources have remaining value and broader scope, so they are lineage references rather than claims of full absorption. Every requirement needed for this feature is stated in this folder. Existing domain validators and accepted-state commands remain the implementation authority for their invariants.

## What the experiment establishes

The pinned `@agentclientprotocol/codex-acp@1.12.0` adapter with bundled Codex `0.154.0` completed live synthetic native research and proposal generation using an existing ChatGPT login. Native cancellation retained partial text; relaunch/resume preserved six messages and the pending proposal. Eight relay tests and seven native tests passed. The XCUITest runner timed out enabling automation, so its result is not a UI pass; direct native checks supply separate evidence.

It does **not** establish clean installation, interactive login/expiry, production database migration, complete runtime isolation, crash-time reconciliation, deletion of provider history or usefulness on real projects. The prototype's manually launched helper, transient pairing, JSON state file, live-only activity list and wholesale suppression of load replay are not the production design.

## Current platform references

Official documentation checked 2026-09-17 describes Codex-managed ChatGPT authentication and restricted sandbox read roots. These provide candidate mechanisms for P0, not a claim that the pinned ACP adapter exposes them. Generate/check schemas against the actual selected runtime during implementation. [Codex App Server documentation](https://learn.chatgpt.com/docs/app-server)

The proposed default remains ACP for the first adapter. If its exposed controls cannot satisfy the feature's restrictions, P0 must record a concrete decision: qualify a narrow adapter change, qualify a direct supported Codex integration behind the same ProjectOS interface, or leave Codex unavailable for real context. A transport decision is not permission for silent provider/account fallback or to reuse an older rejected spike without new evidence.

## Explicit deferrals

- Other real agent backends; the interface is exercised with a fake implementation.
- Automatic capture of Codex-cited pages. Users may use the existing paste-source flow with authorship/provenance intact.
- External Codex conversation import, synthetic experiment import, agent-session export to another machine, and cross-account resume.
- Codex-generated Overview/next-action guidance: retain the existing direct-provider workflow, with its own explicit selection; never silently route a Codex selection to it.
- Public installer/signing/notarization distribution work beyond what the personal-use helper needs; App Store feasibility is not asserted.
- Broad filesystem access, shell, coding, MCP/connectors, arbitrary skills/hooks/plugins, browser/computer control and automatic project mutations.

Wrapper-only material omitted from the contract: workflow menus, command-by-command execution chronology and historical reviewer prompts. Evidence artifacts and historical plans are preserved in place.
