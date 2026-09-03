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
//   --guided   generation is constrained to the type, so violations are
//              impossible by construction. If value accuracy is the same, the
//              schema question is settled and free-form is the wrong way to ship.
//
// NOTE: this file has never been compiled — the corpus work happened on Linux.
// Check the API against the current Foundation Models documentation before
// trusting it; the shape is right but names may have moved.

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

    @Guide(description: "yes, no, or unknown. Use unknown when the listing does not state it.")
    let value: Value

    @Guide(description: "A verbatim quote from the listing. Null when value is unknown.")
    let evidence: String?
}

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
    let session = LanguageModelSession(instructions: prompt.system)

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
