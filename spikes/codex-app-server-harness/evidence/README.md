# Harness evidence contract

`harness-run.schema.json` is the committed versioned contract for the sanitized, shareable Story 1.1 summary. Local runs are retained under the ignored `.evidence/<run-id>/` directory:

- `private.json` has mode `0600` and is controlled local evidence. It contains the exact discovered executable and isolated runtime paths required to reproduce and audit the run.
- `summary.json` has mode `0600` and follows `harness-run.schema.json`. It contains correlation and run identifiers, timestamps, tool/runtime versions, safe fingerprints, lifecycle and handshake/shutdown outcomes, isolation comparison, result, and the same-environment reproduction command.

Neither file may contain credentials, account identifiers, authorization headers, raw protocol payloads, raw stderr, Project content, prompts/results, real normal-profile contents, or unrelated local paths. The summary additionally excludes all exact local paths.

Writes use a temporary sibling plus rename for each JSON document. A failed run remains a failed run; evidence-write failure is terminal and must never be reported as a pass.
