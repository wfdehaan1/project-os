import SwiftUI

// Generated from the frontmatter colour contract in
// `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/DESIGN.md`.
//
// Components never read a preset literal. They resolve semantic roles through
// `Theme`, which `ThemeResolver` produces from a preset, an appearance, and the
// system Increase Contrast setting.

/// A flat set of semantic role values for one preset in one appearance.
struct ThemePalette: Equatable {

    let canvas: String
    let sidebar: String
    let surface: String
    let surfaceRaised: String
    let text: String
    let muted: String
    let decorativeDivider: String
    let accent: String
    let accentText: String
    let selection: String
    let tint: String
    let success: String
    let warning: String
    let essentialBoundary: String
    let selectedBoundary: String
    let focusIndicator: String
    let graphEdge: String
    let graphNodeBoundary: String
    let pileDecision: String
    let pileDecisionSuperseded: String
    let pileQuestion: String
    let pileProposal: String
    let pileGround: String
}

/// Replacement values for the load-bearing roles when Increase Contrast is on.
///
/// Only roles that must stay perceivable are overridden; structural surfaces and
/// readable content keep their normal values so theme identity survives.
struct ThemeContrastOverlay: Equatable {

    let essentialBoundary: String
    let selectedBoundary: String
    let focusIndicator: String
    let graphEdge: String
    let graphNodeBoundary: String
    let pileDecision: String
    let pileDecisionSuperseded: String
    let pileQuestion: String
    let pileProposal: String
    let pileGround: String
}

/// The complete definition of one selectable theme preset.
struct ThemePresetDefinition: Identifiable, Equatable {
    let id: ThemePreset
    let displayName: String
    let light: ThemePalette
    let dark: ThemePalette
    let lightContrast: ThemeContrastOverlay
    let darkContrast: ThemeContrastOverlay
}

/// The presets offered globally and as a constrained per-project identity override.
///
/// Adding a preset means adding a case and a definition; no component changes.
enum ThemePreset: String, CaseIterable, Identifiable, Codable {

    case studioPaper
    case signalSlate
    case quietGrove
    case fjordAir
    case aubergineLedger

    var id: String { rawValue }

    /// The global default named by the design spine.
    static let `default`: ThemePreset = .studioPaper

    var definition: ThemePresetDefinition { ThemePresetCatalog.definition(for: self) }
    var displayName: String { definition.displayName }
}

enum ThemePresetCatalog {
    static let all: [ThemePresetDefinition] = ThemePreset.allCases.map(definition(for:))

    static func definition(for preset: ThemePreset) -> ThemePresetDefinition {
        switch preset {

        case .studioPaper: studioPaper
        case .signalSlate: signalSlate
        case .quietGrove: quietGrove
        case .fjordAir: fjordAir
        case .aubergineLedger: aubergineLedger
        }
    }

    private static let studioPaper = ThemePresetDefinition(
        id: .studioPaper,
        displayName: "Studio Paper",
        light: ThemePalette(
            canvas: "#FCFBF8",
            sidebar: "#F3F0EA",
            surface: "#FFFFFF",
            surfaceRaised: "#FFFFFF",
            text: "#24211D",
            muted: "#686158",
            decorativeDivider: "#D8D2C8",
            accent: "#6B4E2E",
            accentText: "#FFFFFF",
            selection: "#E9E1D6",
            tint: "#F7F2E9",
            success: "#2F6B4F",
            warning: "#8A5A00",
            essentialBoundary: "#756B60",
            selectedBoundary: "#6B4E2E",
            focusIndicator: "#6B4E2E",
            graphEdge: "#756B60",
            graphNodeBoundary: "#6B4E2E",
            pileDecision: "#6B4E2E",
            pileDecisionSuperseded: "#756B60",
            pileQuestion: "#756B60",
            pileProposal: "#6B4E2E",
            pileGround: "#756B60"
        ),
        dark: ThemePalette(
            canvas: "#1C1A17",
            sidebar: "#24211D",
            surface: "#28241F",
            surfaceRaised: "#302B25",
            text: "#F3EFE8",
            muted: "#BBB2A6",
            decorativeDivider: "#4B443B",
            accent: "#D6B98B",
            accentText: "#20180F",
            selection: "#3B3126",
            tint: "#29231C",
            success: "#78C69A",
            warning: "#F0BE63",
            essentialBoundary: "#BBB2A6",
            selectedBoundary: "#D6B98B",
            focusIndicator: "#D6B98B",
            graphEdge: "#BBB2A6",
            graphNodeBoundary: "#D6B98B",
            pileDecision: "#D6B98B",
            pileDecisionSuperseded: "#BBB2A6",
            pileQuestion: "#BBB2A6",
            pileProposal: "#D6B98B",
            pileGround: "#BBB2A6"
        ),
        lightContrast: ThemeContrastOverlay(
            essentialBoundary: "#4A4036",
            selectedBoundary: "#3A2410",
            focusIndicator: "#3A2410",
            graphEdge: "#4A4036",
            graphNodeBoundary: "#3A2410",
            pileDecision: "#3A2410",
            pileDecisionSuperseded: "#4A4036",
            pileQuestion: "#4A4036",
            pileProposal: "#3A2410",
            pileGround: "#4A4036"
        ),
        darkContrast: ThemeContrastOverlay(
            essentialBoundary: "#F3EFE8",
            selectedBoundary: "#FFE0B5",
            focusIndicator: "#FFE0B5",
            graphEdge: "#F3EFE8",
            graphNodeBoundary: "#FFE0B5",
            pileDecision: "#FFE0B5",
            pileDecisionSuperseded: "#F3EFE8",
            pileQuestion: "#F3EFE8",
            pileProposal: "#FFE0B5",
            pileGround: "#F3EFE8"
        )
    )

    private static let signalSlate = ThemePresetDefinition(
        id: .signalSlate,
        displayName: "Signal Slate",
        light: ThemePalette(
            canvas: "#F7F9FB",
            sidebar: "#E9EDF1",
            surface: "#FFFFFF",
            surfaceRaised: "#FFFFFF",
            text: "#111820",
            muted: "#52606D",
            decorativeDivider: "#C9D1D9",
            accent: "#174D7A",
            accentText: "#FFFFFF",
            selection: "#D6E4F0",
            tint: "#EDF4F8",
            success: "#176B45",
            warning: "#855800",
            essentialBoundary: "#52606D",
            selectedBoundary: "#174D7A",
            focusIndicator: "#174D7A",
            graphEdge: "#52606D",
            graphNodeBoundary: "#174D7A",
            pileDecision: "#172B3A",
            pileDecisionSuperseded: "#52606D",
            pileQuestion: "#52606D",
            pileProposal: "#174D7A",
            pileGround: "#52606D"
        ),
        dark: ThemePalette(
            canvas: "#10161C",
            sidebar: "#172028",
            surface: "#1B252E",
            surfaceRaised: "#202C36",
            text: "#F1F5F8",
            muted: "#AAB8C3",
            decorativeDivider: "#3B4B57",
            accent: "#7BB7E0",
            accentText: "#09243A",
            selection: "#263C4D",
            tint: "#172731",
            success: "#70CE9A",
            warning: "#EFC267",
            essentialBoundary: "#AAB8C3",
            selectedBoundary: "#7BB7E0",
            focusIndicator: "#7BB7E0",
            graphEdge: "#AAB8C3",
            graphNodeBoundary: "#7BB7E0",
            pileDecision: "#7BB7E0",
            pileDecisionSuperseded: "#AAB8C3",
            pileQuestion: "#AAB8C3",
            pileProposal: "#7BB7E0",
            pileGround: "#AAB8C3"
        ),
        lightContrast: ThemeContrastOverlay(
            essentialBoundary: "#2E3A44",
            selectedBoundary: "#062A47",
            focusIndicator: "#062A47",
            graphEdge: "#2E3A44",
            graphNodeBoundary: "#062A47",
            pileDecision: "#062A47",
            pileDecisionSuperseded: "#2E3A44",
            pileQuestion: "#2E3A44",
            pileProposal: "#062A47",
            pileGround: "#2E3A44"
        ),
        darkContrast: ThemeContrastOverlay(
            essentialBoundary: "#F1F5F8",
            selectedBoundary: "#B9E1FF",
            focusIndicator: "#B9E1FF",
            graphEdge: "#F1F5F8",
            graphNodeBoundary: "#B9E1FF",
            pileDecision: "#B9E1FF",
            pileDecisionSuperseded: "#F1F5F8",
            pileQuestion: "#F1F5F8",
            pileProposal: "#B9E1FF",
            pileGround: "#F1F5F8"
        )
    )

    private static let quietGrove = ThemePresetDefinition(
        id: .quietGrove,
        displayName: "Quiet Grove",
        light: ThemePalette(
            canvas: "#FAFBF8",
            sidebar: "#EDF1E9",
            surface: "#FFFFFF",
            surfaceRaised: "#FFFFFF",
            text: "#182019",
            muted: "#586358",
            decorativeDivider: "#CCD4C8",
            accent: "#2E6045",
            accentText: "#FFFFFF",
            selection: "#DCE9DD",
            tint: "#EEF5EC",
            success: "#236641",
            warning: "#825B0B",
            essentialBoundary: "#586358",
            selectedBoundary: "#2E6045",
            focusIndicator: "#2E6045",
            graphEdge: "#586358",
            graphNodeBoundary: "#2E6045",
            pileDecision: "#315B45",
            pileDecisionSuperseded: "#586358",
            pileQuestion: "#586358",
            pileProposal: "#2E6045",
            pileGround: "#586358"
        ),
        dark: ThemePalette(
            canvas: "#131813",
            sidebar: "#1B231C",
            surface: "#202921",
            surfaceRaised: "#263128",
            text: "#EEF4ED",
            muted: "#AFBCAF",
            decorativeDivider: "#3D4C3E",
            accent: "#8FC59E",
            accentText: "#102817",
            selection: "#29402F",
            tint: "#1B2B20",
            success: "#83D29E",
            warning: "#E9C06B",
            essentialBoundary: "#AFBCAF",
            selectedBoundary: "#8FC59E",
            focusIndicator: "#8FC59E",
            graphEdge: "#AFBCAF",
            graphNodeBoundary: "#8FC59E",
            pileDecision: "#8FC59E",
            pileDecisionSuperseded: "#AFBCAF",
            pileQuestion: "#AFBCAF",
            pileProposal: "#8FC59E",
            pileGround: "#AFBCAF"
        ),
        lightContrast: ThemeContrastOverlay(
            essentialBoundary: "#364236",
            selectedBoundary: "#153D29",
            focusIndicator: "#153D29",
            graphEdge: "#364236",
            graphNodeBoundary: "#153D29",
            pileDecision: "#153D29",
            pileDecisionSuperseded: "#364236",
            pileQuestion: "#364236",
            pileProposal: "#153D29",
            pileGround: "#364236"
        ),
        darkContrast: ThemeContrastOverlay(
            essentialBoundary: "#EEF4ED",
            selectedBoundary: "#C7F0D0",
            focusIndicator: "#C7F0D0",
            graphEdge: "#EEF4ED",
            graphNodeBoundary: "#C7F0D0",
            pileDecision: "#C7F0D0",
            pileDecisionSuperseded: "#EEF4ED",
            pileQuestion: "#EEF4ED",
            pileProposal: "#C7F0D0",
            pileGround: "#EEF4ED"
        )
    )

    private static let fjordAir = ThemePresetDefinition(
        id: .fjordAir,
        displayName: "Fjord Air",
        light: ThemePalette(
            canvas: "#F9FCFD",
            sidebar: "#EEF5F7",
            surface: "#FFFFFF",
            surfaceRaised: "#FFFFFF",
            text: "#132126",
            muted: "#56676D",
            decorativeDivider: "#C9D9DD",
            accent: "#0B6070",
            accentText: "#FFFFFF",
            selection: "#D6EDF1",
            tint: "#EAF6F7",
            success: "#18704A",
            warning: "#8B5900",
            essentialBoundary: "#56676D",
            selectedBoundary: "#0B6070",
            focusIndicator: "#0B6070",
            graphEdge: "#56676D",
            graphNodeBoundary: "#0B6070",
            pileDecision: "#1B6570",
            pileDecisionSuperseded: "#56676D",
            pileQuestion: "#56676D",
            pileProposal: "#0B6070",
            pileGround: "#56676D"
        ),
        dark: ThemePalette(
            canvas: "#0F181B",
            sidebar: "#172226",
            surface: "#1B292D",
            surfaceRaised: "#213136",
            text: "#EDF6F7",
            muted: "#ABC0C4",
            decorativeDivider: "#3A5055",
            accent: "#79CBD4",
            accentText: "#082A30",
            selection: "#244047",
            tint: "#172B30",
            success: "#75D29B",
            warning: "#F1BF61",
            essentialBoundary: "#ABC0C4",
            selectedBoundary: "#79CBD4",
            focusIndicator: "#79CBD4",
            graphEdge: "#ABC0C4",
            graphNodeBoundary: "#79CBD4",
            pileDecision: "#79CBD4",
            pileDecisionSuperseded: "#ABC0C4",
            pileQuestion: "#ABC0C4",
            pileProposal: "#79CBD4",
            pileGround: "#ABC0C4"
        ),
        lightContrast: ThemeContrastOverlay(
            essentialBoundary: "#34454A",
            selectedBoundary: "#004454",
            focusIndicator: "#004454",
            graphEdge: "#34454A",
            graphNodeBoundary: "#004454",
            pileDecision: "#004454",
            pileDecisionSuperseded: "#34454A",
            pileQuestion: "#34454A",
            pileProposal: "#004454",
            pileGround: "#34454A"
        ),
        darkContrast: ThemeContrastOverlay(
            essentialBoundary: "#EDF6F7",
            selectedBoundary: "#B8F4FB",
            focusIndicator: "#B8F4FB",
            graphEdge: "#EDF6F7",
            graphNodeBoundary: "#B8F4FB",
            pileDecision: "#B8F4FB",
            pileDecisionSuperseded: "#EDF6F7",
            pileQuestion: "#EDF6F7",
            pileProposal: "#B8F4FB",
            pileGround: "#EDF6F7"
        )
    )

    private static let aubergineLedger = ThemePresetDefinition(
        id: .aubergineLedger,
        displayName: "Aubergine Ledger",
        light: ThemePalette(
            canvas: "#FBF9FC",
            sidebar: "#F1EDF3",
            surface: "#FFFFFF",
            surfaceRaised: "#FFFFFF",
            text: "#241B27",
            muted: "#675B6A",
            decorativeDivider: "#D8CDD9",
            accent: "#67436C",
            accentText: "#FFFFFF",
            selection: "#E9DDEB",
            tint: "#F6EEF6",
            success: "#276848",
            warning: "#865900",
            essentialBoundary: "#675B6A",
            selectedBoundary: "#67436C",
            focusIndicator: "#67436C",
            graphEdge: "#675B6A",
            graphNodeBoundary: "#67436C",
            pileDecision: "#57375D",
            pileDecisionSuperseded: "#675B6A",
            pileQuestion: "#675B6A",
            pileProposal: "#67436C",
            pileGround: "#675B6A"
        ),
        dark: ThemePalette(
            canvas: "#191419",
            sidebar: "#231C24",
            surface: "#2A222B",
            surfaceRaised: "#322833",
            text: "#F5EDF5",
            muted: "#C1B1C2",
            decorativeDivider: "#4D3E4F",
            accent: "#D1A8D3",
            accentText: "#29172B",
            selection: "#402F42",
            tint: "#2C202D",
            success: "#7ACE9B",
            warning: "#F0BF65",
            essentialBoundary: "#C1B1C2",
            selectedBoundary: "#D1A8D3",
            focusIndicator: "#D1A8D3",
            graphEdge: "#C1B1C2",
            graphNodeBoundary: "#D1A8D3",
            pileDecision: "#D1A8D3",
            pileDecisionSuperseded: "#C1B1C2",
            pileQuestion: "#C1B1C2",
            pileProposal: "#D1A8D3",
            pileGround: "#C1B1C2"
        ),
        lightContrast: ThemeContrastOverlay(
            essentialBoundary: "#453947",
            selectedBoundary: "#45214B",
            focusIndicator: "#45214B",
            graphEdge: "#453947",
            graphNodeBoundary: "#45214B",
            pileDecision: "#45214B",
            pileDecisionSuperseded: "#453947",
            pileQuestion: "#453947",
            pileProposal: "#45214B",
            pileGround: "#453947"
        ),
        darkContrast: ThemeContrastOverlay(
            essentialBoundary: "#F5EDF5",
            selectedBoundary: "#F0C9F2",
            focusIndicator: "#F0C9F2",
            graphEdge: "#F5EDF5",
            graphNodeBoundary: "#F0C9F2",
            pileDecision: "#F0C9F2",
            pileDecisionSuperseded: "#F5EDF5",
            pileQuestion: "#F5EDF5",
            pileProposal: "#F0C9F2",
            pileGround: "#F5EDF5"
        )
    )

}
