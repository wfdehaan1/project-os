- source_spec: `_bmad-output/implementation-artifacts/spec-improve-guided-screening-instruction.md`
  summary: Preserve prior screening evidence by documenting versioned output filenames for reruns.
  evidence: The existing README commands write directly to responses-guided.jsonl and responses-freeform.jsonl, which can overwrite earlier experimental evidence.
- source_spec: `_bmad-output/implementation-artifacts/spec-improve-guided-screening-instruction.md`
  summary: Align fabricated-evidence grading with the listing-only exact-span contract.
  evidence: The current checker searches the entire user prompt including the question, normalizes candidate evidence, and exempts short spans, so it does not mechanically enforce the stricter guided instruction.
