# Pinned Protocol Contract

This directory contains the Story 1.2 spike compatibility pin. It is an exact-build validation artifact, not a semantic version range, automatic update policy, or production support promise.

`supported-runtime-manifest.json` was generated from the owned immutable snapshot of the resolved `codex-cli 0.145.0` Darwin arm64 executable. The manifest records the location-independent binary SHA-256, exact stable generator argument arrays, complete sorted JSON/TypeScript schema inventories, per-file SHA-256 digests, separate aggregate digests, direction-specific required methods, recognized forbidden inbound surfaces, and the only dispatch enabled by this story: `initialize` followed once by `initialized` with `experimentalApi: false`.

## Digest procedure

For each JSON or TypeScript tree:

1. Reject symlinks, non-regular files, malformed JSON files, control characters, backslashes, absolute paths, dot segments, duplicate normalized paths, and configured file/byte limits.
2. Normalize each relative filename to a POSIX path and sort by Unicode code point. JSON files are parsed, recursively object-key sorted by code point, serialized with `JSON.stringify` and no whitespace, then SHA-256 hashed; this removes generator map-order noise without hiding semantic drift. TypeScript files are retained and SHA-256 hashed as raw bytes.
3. Create the exact UTF-8 bytes of `JSON.stringify({algorithm:"projectos-schema-tree-sha256-v1",files:[{path,sha256},...]})` with that key order and no pretty-print whitespace.
4. SHA-256 those aggregate bytes. Absolute temporary paths, timestamps, metadata, and directory enumeration order are excluded.

## Generation and refresh discipline

The stable logical commands are:

```text
$CODEX app-server generate-json-schema --out $JSON_OUT
$CODEX app-server generate-ts --out $TS_OUT
```

They must run with argument arrays, `shell: false`, the isolated allowlisted Story 1.1 environment, bounded output and time, and no inherited terminal. Do not add `--experimental`, `--prettier`, or `--strict-config` to schema generation.

Normal validation never rewrites the manifest. A refresh is a deliberate evidence review: resolve an eligible non-app-bundle candidate, snapshot its open-file bytes into the private instance directory, reproduce version/binary/schema/method evidence twice, review all drift, update the manifest intentionally, and run the complete offline and opt-in live protocol suites. A mismatch must fail closed before App Server spawn or provider action.

Exact generated schemas and local executable/output paths are private run evidence. They are never committed or copied into shareable diagnostics.

## Validation commands

Deterministic, offline, fake-backed validation:

```sh
npm ci && npm run validate:protocol
```

Explicit installed-runtime validation and the opt-in macOS smoke:

```sh
npm run protocol:validate
npm run protocol:validate -- --restart
npm run test:protocol:live
npm run validate:protocol:live
```

Run these from this harness directory with Node.js `24.18.1`. The installed runtime must match the manifest's build, platform, architecture, binary bytes, stable schema trees, and required direction-specific method sets exactly. Exit `0` means compatible, initialized, stopped, and evidenced; exit `1` is a normalized validation failure; exit `2` is CLI usage failure. A mismatch never refreshes the manifest automatically and never starts App Server when detected before spawn.

The same-environment path-free reproduction command retained in protocol summaries is `npm ci && npm run protocol:validate`, or `npm ci && npm run protocol:validate -- --restart` when restart was requested. Manifest refresh review additionally requires two complete offline passes and `npm run test:protocol:live` on the supported macOS runtime.
