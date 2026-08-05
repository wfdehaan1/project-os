# Harness evidence contract

`harness-run.schema.json` is the committed versioned contract for the sanitized, shareable Story 1.1 summary. Local runs are retained under the ignored `.evidence/<run-id>/` directory:

- `private.json` has mode `0600` and is controlled local evidence. It contains the exact discovered executable and isolated runtime paths required to reproduce and audit the run.
- `summary.json` has mode `0600` and follows `harness-run.schema.json`. It contains correlation and run identifiers, timestamps, tool/runtime versions, safe fingerprints, lifecycle and handshake/shutdown outcomes, isolation comparison, result, and the same-environment reproduction command.
- `protocol-private.json` has mode `0600`. It retains the exact resolved and snapshot executable paths, binary-content SHA-256, per-attempt isolated generator output paths and exact argv, full parsed manifest/comparison inputs, exact schema inventories/digests, detected methods, structural transcript, lifecycle/shutdown result, and opaque diagnostic reference.
- `protocol-schemas/` and every nested directory have mode `0700`; copied schema files have mode `0600`. Each successful generator attempt keeps its exact JSON and TypeScript trees under `attempt-<generation>/`.
- `protocol-summary.json` has mode `0600` and follows `protocol-validation-run.schema.json`. It contains only the exact build/platform/architecture, `binaryContentSha256`, manifest identity/digest, digest algorithm, sorted relative schema paths/digests, aggregate digests, approved methods, compatibility/lifecycle/shutdown outcomes, opaque diagnostics, structural transcript, logical placeholder argv, and path-free reproduction command.
- `protocol-transcript.json` has mode `0600` and duplicates only the shareable structural transcript for focused inspection. Unknown method text is replaced with `$UNRECOGNIZED`.

No shareable file may contain credentials, tokens, API keys, account identifiers, authorization headers, environment values, raw protocol payloads/lines, payload hashes, raw stderr, Project content, prompts/results, real normal-profile contents, or local paths. Private protocol evidence still never retains raw JSON-RPC payloads or stderr: it starts from structural transcript entries rather than persisting sensitive data and attempting to clean it later.

Story 1.3 writes `authentication-summary.json` in a separate atomically-published `*-authentication/` evidence directory. It follows `authentication-validation-run.schema.json` and contains only normalized state, retryability, plan category, expected-Pro result, unsupported/supported device-code capability, logout, profile-isolation, credential-ownership, stop condition, and the opt-in reproduction command (`PROJECTOS_LIVE_AUTH=1 npm run test:auth:live`). It contains no browser URL, login ID, account field, raw notification, token, credential file, local path, or provider error.

Story 1.4 writes atomic `allowance-summary.json` records in separate `*-allowance/` directories. They retain only normalized bucket usage, window duration, reset timestamp, reached-limit classification, runtime version, readiness, remedy, correlation ID, and failure code. Credentials, account data, provider event types, raw payloads, URLs, paths, prompts, and results are rejected before retention.

Story 1.5 writes atomic `structured-output-summary.json` records in separate `*-structured-output/` directories. They retain only per-artifact-type aggregate scoring metrics, score, stop conditions, correlation ID, and whether containment was unavailable or attested. The recorder rejects fixture/project names, preview text, proposal values, provider replies, raw payloads, identities, credentials, URLs, and paths. A missing containment attestation produces a metric-only reject without runtime discovery, child spawn, thread, or turn dispatch.

Story 1.6 writes atomic `containment-summary.json` records in separate `*-containment/` directories and follows `containment-validation-run.schema.json`. It retains only run/correlation IDs, runtime and manifest digests, allowed-root count, zero writable roots, Context Preview instruction-source records, boundary classification, four structural observations, and stop conditions. It rejects paths, prompts, project content, raw payloads, URLs, account identity, credentials, and contradictory or malformed evidence. The current adapter writes a reject before discovery/spawn when an independently verified preventive boundary is unavailable; it never treats post-hoc detection or cleanup as a pass.

The recorder builds the complete base-plus-protocol record in one `0700` sibling staging directory, writes and syncs `0600` files, rejects traversal, symlinks, non-regular files, duplicate attachment destinations, and bounded-size violations, then publishes the run with one directory rename. A failure never publishes the staging directory as a completed run; cleanup of an unpublished staging directory is best-effort if the filesystem itself refuses removal. Evidence-write failure is terminal and is reported only after every owned generator/App Server child has been reaped.

Run deterministic, offline, fake-backed protocol validation with:

```sh
npm ci && npm run validate:protocol
```

Reproduce installed-runtime evidence only in the same supported runtime, Node, npm, platform, and architecture environment with:

```sh
npm ci && npm run protocol:validate
```

Use `npm run test:protocol:live` only for the explicit supported-macOS exact-runtime smoke, or `npm run validate:protocol:live` to run the focused offline checks before that smoke. Both live commands perform no authentication, account, thread, turn, model, or provider action. A run invoked with `--restart` retains `npm ci && npm run protocol:validate -- --restart` as its reproduction command.
