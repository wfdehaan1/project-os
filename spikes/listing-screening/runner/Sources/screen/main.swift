// Runs the screening prompts against Apple's on-device Foundation Models and
// writes one JSON line per answer, for `npm run grade` to score.
//
//   swift run screen ../fixtures/prompts.jsonl > ../responses-freeform.jsonl
//   swift run screen --guided ../fixtures/prompts.jsonl > ../responses-guided.jsonl
//
// The two modes answer different questions, and both are worth running:
//
//   free-form  the model is told the JSON schema in the instructions and left to
//              obey it. Schema violations here are a real result — D9 assumes a
//              strict schema is cheap, and this is where that gets tested.
//   --guided   generation constrains each field to its declared type, but the
//              generated type cannot enforce the dependency between `value` and
//              `evidence`. The grader therefore still checks that invariant.
//
// Foundation Models requires macOS 26+ / Apple silicon. Keep compiling this
// runner against the current SDK when its API usage or generated shape changes.

import Foundation
import FoundationModels

// MARK: - Wire format, matching src/types.ts

struct Prompt: Codable {
    let id: String
    let criterion: String
    let mode: String
    let system: String
    let user: String
}

struct RecordedResponse: Codable {
    let id: String
    let criterion: String
    let mode: String
    let raw: String
    let meta: [String: String]
}

/// The guided-generation counterpart of ANSWER_JSON_SCHEMA in src/schema.ts.
/// Keep the two in step: the grader validates against the TypeScript one.
@Generable
struct Answer {
    @Generable
    enum Value: String {
        case yes
        case no
        case unknown
    }

    @Guide(description: "The criterion id exactly as given in the question.")
    let criterion: String

    @Guide(description: "Classify only after locating decisive listing text. Silence, ambiguity, or a contradiction relevant to the criterion means unknown.")
    let value: Value

    @Guide(description: "For yes or no, copy a short exact contiguous span from the listing data or seller description that proves the value; never quote the question, paraphrase, translate, combine, or invent text. For unknown, produce Swift nil, never a textual placeholder such as 'null' or 'unknown'.")
    let evidence: String?
}

private let guidedDecisionInstructions = """
Guided decision procedure:
1. First locate a short, exact, contiguous span in the listing data or seller description that decisively supports "yes" or "no". Never use the question or instructions as evidence. Do not paraphrase, translate, combine passages, or invent evidence.
2. If no decisive listing span exists, or statements relevant to the criterion conflict, answer "unknown" with evidence nil.
3. For "unknown", produce Swift nil for evidence, never a string such as "null", "unknown", or an explanation.
"""

private let guidedWarrantyInstructions = """
For warranty_included, decide whether warranty above the statutory warranty is included in the asking price:
- "yes": the listing explicitly says this additional warranty is included in the asking price or in an included/default package at no extra cost. An optional extended-warranty upgrade does not negate qualifying warranty already included at no extra cost.
- "no": the asking price explicitly excludes this warranty, or it is available only through an optional or extra-cost package. Optional means "no" even when no package price is shown, and extra cost overrides words such as "standard" or "default".
- "unknown": the listing is silent or ambiguous, mentions only statutory warranty, or conflicts about whether any qualifying warranty is included. Different included and optional warranty tiers are not by themselves a conflict.
- The warranty and warrantyExists fields alone never prove inclusion or exclusion from the asking price. Their absence or false value alone is "unknown", not "no".
"""

// MARK: - Arguments

var arguments = Array(CommandLine.arguments.dropFirst())
let guided = arguments.contains("--guided")
arguments.removeAll { $0.hasPrefix("--") }

guard let path = arguments.first else {
    FileHandle.standardError.write(Data("usage: screen [--guided] <prompts.jsonl>\n".utf8))
    exit(2)
}

let model = SystemLanguageModel.default
guard model.availability == .available else {
    FileHandle.standardError.write(Data("model unavailable: \(model.availability)\n".utf8))
    exit(1)
}

let lines = try String(contentsOfFile: path, encoding: .utf8)
    .split(separator: "\n")
    .map(String.init)
    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.withoutEscapingSlashes]

var failures = 0

for (index, line) in lines.enumerated() {
    let prompt = try decoder.decode(Prompt.self, from: Data(line.utf8))

    // A fresh session per prompt. Reusing one would let an earlier listing's
    // reasoning leak into the next answer, which is a confound, not a feature.
    let guidedInstructions = prompt.criterion == "warranty_included"
        ? "\(guidedDecisionInstructions)\n\n\(guidedWarrantyInstructions)"
        : guidedDecisionInstructions
    let instructions = guided ? "\(prompt.system)\n\n\(guidedInstructions)" : prompt.system
    let session = LanguageModelSession(instructions: instructions)

    let started = Date()
    var raw: String
    do {
        if guided {
            let answer = try await session.respond(to: prompt.user, generating: Answer.self).content
            let evidence = answer.evidence.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" } ?? "null"
            raw = """
            {"criterion":"\(answer.criterion)","value":"\(answer.value.rawValue)","evidence":\(evidence)}
            """
        } else {
            raw = try await session.respond(to: prompt.user).content
        }
    } catch {
        // Guardrail refusals and context overflows are results too: record them
        // so the grader counts them as schema violations rather than losing them.
        raw = "ERROR: \(error)"
        failures += 1
    }

    let elapsed = Int(Date().timeIntervalSince(started) * 1000)
    let record = RecordedResponse(
        id: prompt.id,
        criterion: prompt.criterion,
        mode: prompt.mode,
        raw: raw,
        meta: [
            "runner": guided ? "foundation-models-guided" : "foundation-models-freeform",
            "latency_ms": String(elapsed),
        ]
    )
    print(String(decoding: try encoder.encode(record), as: UTF8.self))

    FileHandle.standardError.write(Data("\(index + 1)/\(lines.count) \(elapsed)ms\n".utf8))
}

FileHandle.standardError.write(Data("done, \(failures) errored\n".utf8))
