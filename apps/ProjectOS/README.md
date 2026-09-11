# ProjectOS

ProjectOS is a personal-use native macOS application for carrying durable project context across conversations. The MVP keeps projects, conversation threads and drafts, pasted sources, reviewed knowledge, change history, and return outcomes locally. Ollama and OpenRouter are explicit inference options; opening or browsing a project never sends content.

## Requirements

- macOS 26
- Xcode 26 with Swift 6.2
- Ollama for optional on-Mac inference, or an OpenRouter account and API key for optional external inference

Local project work, review, browsing, export, restore, and deletion must remain available without either provider.

## Build and run

From `apps/ProjectOS`:

```sh
rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedData -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES build
rtk proxy open ProjectOS.xcodeproj
```

Choose the shared `ProjectOS` scheme in Xcode and run it on **My Mac**. The personal build uses local signing and does not require App Store membership or Apple Foundation Models entitlements.

Run the local package tests separately:

```sh
rtk swift test --package-path Packages/ProjectOSCore
```

Run app and UI tests without contacting an inference provider:

```sh
rtk xcodebuild test -project ProjectOS.xcodeproj -scheme ProjectOS -destination 'platform=macOS'
```

The implementation report records which of these commands actually passed in this checkout. A successful fake-provider or transport-fixture test does not qualify a real model.

## Data and credentials

The SQLite store is resolved with the system Application Support directory and stored as `ProjectOS/projectos.sqlite3`. In a sandboxed build, that location is inside ProjectOS's app container. Removing the app does not necessarily remove container data or system backups.

OpenRouter keys are stored through Security.framework Keychain and are not written to the project database or project exports. Provider/model choices are explicit. ProjectOS does not silently retry, change providers/models, or move Ollama requests away from a configured loopback address.

## Provider setup

### Ollama

1. Install and start Ollama yourself; ProjectOS does not manage runtimes or download models.
2. Make the intended model available locally.
3. In Provider Settings, choose Ollama, keep or set a loopback IP/port (the default is `http://127.0.0.1:11434`), and enter the exact model ID.
4. Enter the model's documented context-window token count and output budget.
5. Save, then run the explicit connectivity test.

Connectivity means the endpoint responded. It does not prove the model executes locally or meets the chat/proposal contract. Qualification additionally requires a recorded offline execution and capability/quality walkthrough on the intended Mac. Cloud-backed Ollama models are outside this slice.

### OpenRouter

1. In Provider Settings, choose OpenRouter.
2. Enter one stable model ID and one pinned upstream provider route. `auto`, fallback lists, and silent route changes are not allowed.
3. Save the API key to Keychain and run the explicit connectivity test.
4. Enter the documented context window/output budget and a concrete approved per-request spending ceiling; where available, also use a provider-side key limit. ProjectOS sends conservative OpenRouter `max_price` limits and rejects returned routing metadata that does not match the pinned model/provider.

OpenRouter is external and may retain data or incur charges independently. Unknown returned usage is shown as unknown, not zero.

## Export, verify, and restore

From Project Settings, choose **Export Project…** and select a new destination. ProjectOS writes into a sibling staging directory, verifies it, and only then publishes the completed export directory. It never overwrites an existing destination.

An export contains:

- `README.md`, explaining the archive;
- `project.md`, a human-readable inventory;
- `project.json`, the complete versioned project graph; and
- `manifest.json`, with schema metadata, byte counts, and SHA-256 checksums.

The portable graph represents sources, complete/incomplete transcript state, accepted artifact versions, relations, proposal/review history, context and job records, recommendations, changes, drafts, and return outcomes. Credentials and runtime caches are rejected at the archive boundary.

Choose **Restore as New Project…** to import an export. ProjectOS validates the directory, supported schema, every checksum, credential-like fields, project ownership, unique IDs, and referential integrity before it calls the store. Restore creates a new project root, remaps every record/reference consistently, retains original IDs as import metadata, and inserts the graph in one transaction. It never overwrites an existing project; validation or store failure publishes no partial project.

## Permanent deletion

Project deletion is intentionally separate from artifact removal. The application must offer a verified export first (which may be explicitly declined), require the displayed typed confirmation, fence project writes, cancel active jobs, reject late completion events, and remove app-managed project content atomically.

Deletion does **not** remove separately saved exports, system backups, shared local models, the separately managed OpenRouter Keychain item, or data independently retained by an external provider. It is not secure forensic erasure or remote account deletion. Remove the OpenRouter credential separately in Provider Settings.

## Validation status

See [docs/implementation-report.md](docs/implementation-report.md) for exact commands, results, unrun live checks, and known integration gaps. Personal usefulness can only be recorded after real use; generated text and automated tests cannot establish it.
