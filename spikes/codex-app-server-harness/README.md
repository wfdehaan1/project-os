# ProjectOS Codex App Server Harness

Disposable, provider-neutral validation harness for ProjectOS Story 1.1. It discovers a supported `codex` executable, creates an isolated runtime profile, performs only the App Server `initialize`/`initialized` handshake over stdio, records evidence, and terminates the exact child it started.

This is not a production app scaffold. It does not authenticate, start a thread or turn, call a model, mutate Canonical State, select the future SwiftUI/AppKit stack, or prove the compatibility, authentication, allowance, structured-output, preventive-containment, restore, or provider-neutrality gates owned by Stories 1.2–1.9.

## Prerequisites

- macOS in the same supported environment being evaluated
- Node.js 24.18.1 and npm (the exact baseline is in `.nvmrc` and `package.json`)
- a supported `codex` CLI discoverable through the invoking `PATH` for the opt-in live smoke

Install the pinned development dependencies with `npm ci`.

## Commands

```sh
npm run typecheck
npm test
npm run validate
npm run test:live
npm run validate:full
```

`npm test` and `npm run validate` are deterministic, offline, and account-free. `npm run test:live` is opt-in: it discovers the installed CLI and performs version capture plus initialize/initialized/owned shutdown only. It never logs in or starts provider work.

To reproduce the complete evidence run on the same supported macOS environment:

```sh
npm ci && npm run validate:full
```

## Evidence and exit codes

Live runs write permission-restricted local evidence beneath `.evidence/<run-id>/`. `private.json` contains the exact resolved executable and isolated paths required for local verification; `summary.json` is sanitized and shareable. The directory is ignored and must not be committed.

- `0`: validation passed and required evidence was retained
- `1`: discovery, initialization, isolation, shutdown, evidence, or test validation failed
- `2`: command usage or explicit live-smoke prerequisite failure

Failures include a ProjectOS correlation identifier and stable code. They never enable a production provider action or Canonical State operation.
