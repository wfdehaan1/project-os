# ProjectOS implementation report

Date: 2026-09-11

Spec: `_bmad-output/specs/spec-projectos/SPEC.md` and its three companions
Baseline commit: `37bf2083b4d1d9b1f4b98e6445caf2767c1ec481`

This report separates implemented behavior, automated evidence, live verification, and personal usefulness. Deterministic tests do not qualify a real model.

## Implemented

- Native sandboxed SwiftUI macOS application and shared Xcode scheme under `apps/ProjectOS`.
- SQLite local store with schema versioning and tested v1 migration, foreign keys, serialized writes, fail-closed reads, atomic accepted changes, injected rollback, revision checks, idempotent acceptance, dependency-set acceptance, explicit normalized decision supersession, typed relationships, historical removal with relation cleanup, and compensating undo that reopens proposal review.
- Library, project rename/description, labelled exact-text paste intake (250,000-character limit), Overview, Conversation, Knowledge inspector/editor, a recoverable native project-updates inspector that preserves the conversation at narrow window sizes, project settings, and local return-outcome form.
- A persisted conversation list with independently durable per-thread drafts; complete/partial/failed/cancelled messages; one active inference job per project; frozen visible context; explicit send/proposal/next-action requests; cancellation; interrupted-job recovery; stale structured-result rejection; and no inference on navigation.
- A Swift package containing provider-neutral domain records, bounded context construction, the bundled strict proposal schema, semantic/evidence validation, and the accepted-change engine.
- Real Ollama NDJSON and OpenRouter SSE adapters through `URLSession`, explicit provider/model/boundary descriptors, strict routing/no fallback, conservative context bounds, cancellation, redacted failures, usage when returned, and a Keychain-only OpenRouter credential.
- The app submits the bundled core proposal schema and runs the same core semantic validator before proposals enter SQLite. Evidence is exact Unicode text from selected versions, opens the retained record with the exact span highlighted, and remains labelled when AI-authored. Decision acceptance also requires an explicit user confirmation in the review UI.
- Revision-bound next-action guidance citing accepted records. It is never generated on Overview open, can be dismissed without changing project truth, and displays stale after an accepted-state revision change.
- Checksummed, human-readable staged export from one serialized snapshot; validation-before-write restore as a separate identity; fail-closed ID/reference remapping including change snapshots; outcomes, per-conversation drafts, contexts/jobs and returned usage/routing metadata, embedded relations, recommendations, and proposal history; typed-confirmation deletion with a revision-matched export receipt and durable write tombstone that rejects late completions.
- OpenRouter requests pin one provider, disable fallback, opt into returned routing metadata, reject a mismatched model/route, persist returned usage/cost (unknown remains unknown), and translate the approved per-request ceiling into conservative prompt/completion/request `max_price` limits.

## Automated verification

### Core package

From `apps/ProjectOS/Packages/ProjectOSCore`:

```sh
rtk swift test
```

Result: **passed**, 12 tests in 3 suites. Coverage includes exact Unicode/repeated quotes, incomplete-message exclusion, known/exceeded bounds, strict schema and unknown properties, stale generation, assistant-only decision evidence, dependencies, idempotency, supersession/undo, and relation-preserving removal/undo.

### Native build

From `apps/ProjectOS`:

```sh
rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedData -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
```

Result: **passed**. The cache paths keep SwiftPM/Xcode output in writable temporary storage.

### App/store/archive tests

```sh
rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedData -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO -only-testing:ProjectOSTests test
```

Result: **passed**, 18 tests. These exercise relaunch persistence and project isolation, multi-conversation/draft isolation, exact Dutch/Unicode source text, schema-v1 migration, rollback, stale/idempotent acceptance, dependency invalidation, explicit normalized decision replacement and restored review after undo, accepted state/research qualification, checksummed export/separate-copy restore including restored undo history, corrupt-archive rejection without partial state, deletion-fence rejection of late writes, split UTF-8 and SSE framing, local-only Ollama configuration, pinned/capped OpenRouter configuration, error classification, and credential redaction.

### Native launch smoke test

```sh
rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedDataSigned -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES -only-testing:ProjectOSUITests test
```

Result: **passed**, 1 UI test from a fresh signed derived-data path. The launch argument now explicitly disables saved window state, and the test verifies a native window, Library title, and accessible project-creation action. During hardening, a cached signed build surfaced a newer-schema alert; the clean rebuild was inspected and opened Library plus the native creation sheet without that alert. An earlier manual native smoke walkthrough created `Garden Office Smoke Test`, opened Overview and Project Settings, saved exact synthetic text as a labelled source, and verified the Conversation context preview and separate proposal controls. No inference request was sent.

## Provider setup

Ollama requires a loopback URL, exact installed model, and documented context-window value. OpenRouter additionally requires a stable model, pinned upstream provider route, positive approved test spending ceiling, and API key entered through the app into Keychain. Connectivity remains distinct from unverified and qualified status.

The app never installs or starts Ollama, downloads models, reads unrelated credential files, auto-retries, silently falls back, or treats unknown usage as zero.

## Live and personal verification

- Ollama walkthrough: **not run**. Required: Wouter-selected installed local model and offline/local-execution check on the intended Mac.
- OpenRouter walkthrough: **not run**. Required: Wouter-selected model/route, key entered in the app, and an explicit paid-test ceiling.
- Performance corpus benchmark: **not run**. The 1,000-artifact/5,000-relation/10,000-message, 30-attempt p95 measurement remains a live validation task.
- Personal usefulness: **not measured**. The four-to-six-week real-project trial and first return after at least seven days must be recorded by Wouter.

## Known limits

- Typed relationships are persisted and inspectable, but a separate graph canvas is intentionally out of scope.
- Provider correctness is implemented and deterministically exercised at parser/domain level; neither adapter is marked qualified until its real walkthrough passes.
- The actual native flow was visually inspected and captured by the automation session, but no PNG was written into the repository because the UI automation surface does not expose a filesystem-save primitive.
- Xcode reports an installed CoreSimulator/Xcode version mismatch while discovering non-macOS destinations; native macOS build and tests still pass.
