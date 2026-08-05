# ProjectOS Codex App Server Harness

Disposable, provider-neutral validation harness for ProjectOS Stories 1.1–1.4. It discovers a candidate `codex` executable, snapshots its open-file bytes, verifies the exact committed build/binary/stable-schema/method contract, creates an isolated runtime profile, performs the init-only protocol handshake by default, and can explicitly validate managed ChatGPT browser login and a read-only allowance surface on that same owned child.

This is not a production app scaffold. It never handles access/refresh tokens, API keys, authorization headers, account IDs, API credits, device codes, or plaintext credential files; it does not start a thread or turn, call a model, mutate Canonical State, or prove structured-output, preventive-containment, restore, or final provider-neutrality gates. Protocol compatibility is not preventive execution containment.

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
npm run validate:protocol
npm run protocol:validate
npm run protocol:validate -- --restart
npm run test:live
npm run test:protocol:live
npm run validate:protocol:live
PROJECTOS_LIVE_AUTH=1 npm run test:auth:live
npm run validate:allowance
PROJECTOS_LIVE_ALLOWANCE=1 npm run test:allowance:live
npm run validate:full
```

`npm test`, `npm run validate`, and `npm run validate:protocol` are deterministic, offline, fake-backed, and account-free. The focused protocol command includes exact manifest/schema/method, immutable snapshot, deny-by-default transport, restart, concurrency, ownership, and evidence tests.

`npm run protocol:validate` is an explicit installed-runtime validation. It discovers the CLI, uses one immutable snapshot for the version probe, stable schema generation, and App Server spawn, compares the committed exact manifest, initializes with `experimentalApi: false`, shuts down its owned process group, and records evidence. Pass `--path PATH` to control PATH lookup or `--restart` to permit exactly one fresh validation attempt after a safely cleaned failure.

`npm run test:live` retains the Story 1.1 live smoke. `npm run test:protocol:live` is the explicit Story 1.2 macOS live smoke. Both perform only local discovery/checking, initialize/initialized, evidence, and owned shutdown; neither logs in, reads an account, or starts thread/turn/provider work.

`PROJECTOS_LIVE_AUTH=1 npm run test:auth:live` is the sole opt-in interactive browser-login validation. Without that explicit environment setting, `npm run test:auth:live` is skipped; it is never part of `npm test`. It invokes `auth-validate --interactive`, opens only the transient Codex-managed URL, uses the manifest-pinned `account/read`, `account/login/start`, `account/login/cancel`, and `account/logout` subset, then logs out the isolated ProjectOS profile. It prints only a normalized result. Do not run it unless you intend to authenticate an eligible ChatGPT subscription in that disposable profile.

`npm run validate:allowance` replays deterministic fake allowance and terminal-job traces. `PROJECTOS_LIVE_ALLOWANCE=1 npm run test:allowance:live` is separately opt-in and calls only the manifest-pinned, read-only allowance surface. It retains safe bucket values and never offers API-credit fallback, sends a turn, or treats fake replay as live subscription proof.

To reproduce the complete evidence run on the same supported macOS environment:

```sh
npm ci && npm run validate:full
```

For deterministic protocol-only reproduction without an installed runtime:

```sh
npm ci && npm run validate:protocol
```

## Evidence and exit codes

Installed-runtime runs write permission-restricted local evidence beneath `.evidence/<run-id>/`. `private.json` and `summary.json` preserve the Story 1.1 base v1 contract. `protocol-private.json` plus `protocol-schemas/` retain exact local protocol inputs; `protocol-summary.json` and `protocol-transcript.json` contain the path-free, structural companion record. The directory is ignored and must not be committed. See `evidence/README.md` for the private/shareable boundary.

- `0`: validation passed and required evidence was retained
- `1`: snapshot, build/binary/schema/method compatibility, initialization, isolation, shutdown, evidence, or test validation failed
- `2`: protocol-validation CLI usage failure

Failures include a ProjectOS correlation identifier and stable code. They never enable a production provider action or Canonical State operation.
