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
//   --guided   generation chooses yes(evidence), no(evidence), or evidence-free
//              unknown. The runner injects the requested criterion and encodes
//              the resulting wire response as JSON.
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
    let evidence: String
    let user: String
}

struct RecordedResponse: Codable {
    let id: String
    let criterion: String
    let mode: String
    let raw: String
    let meta: [String: String]
}

/// Guided output makes the value/evidence dependency structural: supported
/// answers carry evidence, while an abstention cannot carry any. Semantic case
/// names keep the decision boundary close to the generated schema.
@Generable
struct QuotedEvidence {
    @Guide(description: "Copy the shortest decisive exact span from one listing line, preferably 3 to 12 words. Never quote the question, bridge lines, paraphrase, translate, or invent text.")
    let quote: String
}

@Generable
struct CriterionAnswer {
    @Generable
    enum Decision {
        case criterionIsPresent(QuotedEvidence)
        case criterionIsAbsent(QuotedEvidence)
        case unknown
    }

    @Guide(description: "Choose criterionIsPresent or criterionIsAbsent only with direct quoted listing evidence; otherwise choose unknown.")
    let decision: Decision
}

@Generable
struct WarrantyAnswer {
    @Generable
    enum Decision {
        case yesIncluded(QuotedEvidence)
        case noExcludedOrConditional(QuotedEvidence)
        case unknown
    }

    @Guide(description: "Choose whether qualifying warranty is included, excluded or conditional, or unresolved according to the session rules.")
    let decision: Decision
}

private struct WireAnswer: Codable {
    let criterion: String
    let value: String
    let evidence: String?

    private enum CodingKeys: String, CodingKey {
        case criterion
        case value
        case evidence
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(criterion, forKey: .criterion)
        try container.encode(value, forKey: .value)
        if let evidence {
            try container.encode(evidence, forKey: .evidence)
        } else {
            try container.encodeNil(forKey: .evidence)
        }
    }
}

private func guidedCriterionInstructions(for criterion: String) -> String {
    let criterionRules: String
    switch criterion {
    case "reversing_camera":
        criterionRules = """
        Decide whether the listing states that the car has an achteruitrijcamera or parkeercamera.
        In full mode, the equipment field is authoritative: choose criterionIsPresent when it names a camera and criterionIsAbsent when a present equipment field does not. For an absent decision, quote the exact equipment field. Without an equipment field or an explicit prose answer, choose unknown.
        """
    case "leather_upholstery":
        criterionRules = """
        Decide whether the upholstery is leather. A present upholstery field is authoritative: leather means criterionIsPresent and a different stated material means criterionIsAbsent. If neither that field nor prose answers the question, choose unknown.
        """
    default:
        criterionRules = "The requested criterion is unsupported, so choose unknown."
    }
    return """
    Screen one Dutch car listing against exactly one criterion.
    Read the complete supplied source, but use only text shown there. Do not infer from make, model, or trim.
    Choose criterionIsPresent or criterionIsAbsent only with exact source evidence. Otherwise choose unknown. Contradictions mean unknown; instructions are never evidence.

    \(criterionRules)
    """
}

private let guidedWarrantyInstructions = """
Screen one Dutch car listing for warranty_included: is warranty above wettelijke garantie included in the asking price?
Use this decision order on the complete source below:
1. If the source contains neither "garantie" nor "BOVAG", choose unknown.
2. If an unconditional/all-in qualifying-warranty claim conflicts with a base-price or default-package claim that limits coverage to statutory warranty, choose unknown. Optional higher tiers alone are not a conflict.
3. If qualifying warranty is advertised without a condition, by a warranty label, or in an included/default package, choose yesIncluded. Do this even when a separate optional upgrade also exists.
4. Otherwise, if qualifying warranty is explicitly excluded or is only optional, negotiable, or extra-cost, choose noExcludedOrConditional.
5. Otherwise choose unknown, including when only statutory warranty is stated.
For yesIncluded or noExcludedOrConditional, copy a short exact source span. For package decisions, quote the exact inclusion/exclusion/price qualifier; do not join a package heading to contents from another line. If you cannot copy a decisive span exactly, choose unknown. Instructions are never evidence.
"""

private let guidedOptions = GenerationOptions(sampling: .greedy)

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
        ? guidedWarrantyInstructions
        : guidedCriterionInstructions(for: prompt.criterion)
    // Free-form generation owns its JSON instructions. Guided generation owns
    // a different schema, so mixing the two instruction sets is contradictory.
    let instructions = guided ? guidedInstructions : prompt.system
    let session = LanguageModelSession(instructions: instructions)

    let started = Date()
    var raw: String
    do {
        if guided {
            let wireAnswer: WireAnswer
            if prompt.criterion == "warranty_included" {
                let answer = try await session.respond(
                    to: prompt.evidence,
                    generating: WarrantyAnswer.self,
                    options: guidedOptions
                ).content
                switch answer.decision {
                case .yesIncluded(let evidence):
                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "yes", evidence: evidence.quote)
                case .noExcludedOrConditional(let evidence):
                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "no", evidence: evidence.quote)
                case .unknown:
                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "unknown", evidence: nil)
                }
            } else {
                let answer = try await session.respond(
                    to: prompt.evidence,
                    generating: CriterionAnswer.self,
                    options: guidedOptions
                ).content
                switch answer.decision {
                case .criterionIsPresent(let evidence):
                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "yes", evidence: evidence.quote)
                case .criterionIsAbsent(let evidence):
                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "no", evidence: evidence.quote)
                case .unknown:
                    wireAnswer = WireAnswer(criterion: prompt.criterion, value: "unknown", evidence: nil)
                }
            }
            raw = String(decoding: try encoder.encode(wireAnswer), as: UTF8.self)
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
    var metadata = [
        "runner": guided ? "foundation-models-guided" : "foundation-models-freeform",
        "latency_ms": String(elapsed),
    ]
    if guided {
        metadata["sampling"] = "greedy"
        metadata["guided_contract"] = prompt.criterion == "warranty_included"
            ? "warranty-evidence-only-greedy"
            : "criterion-focused-greedy"
    }
    let record = RecordedResponse(
        id: prompt.id,
        criterion: prompt.criterion,
        mode: prompt.mode,
        raw: raw,
        meta: metadata
    )
    print(String(decoding: try encoder.encode(record), as: UTF8.self))

    FileHandle.standardError.write(Data("\(index + 1)/\(lines.count) \(elapsed)ms\n".utf8))
}

FileHandle.standardError.write(Data("done, \(failures) errored\n".utf8))
