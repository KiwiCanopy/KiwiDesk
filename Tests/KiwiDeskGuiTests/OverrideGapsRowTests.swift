import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A Space's own gaps row (#1775): its readings, its wiring and its
/// place in the overrides box.
@MainActor
@Suite("Per-Space gaps override row (#1775)")
struct OverrideGapsRowTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let dir =
        "Sources/KiwiDesk/Settings/Components/SpaceOverrides/"

    private func mixedGaps() -> Gaps {
        var gaps = Gaps.uniform(10)
        gaps.outer.left = 4
        gaps.inner.vertical = 6
        return gaps
    }

    private static func squashed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    private static func source(_ file: String) throws -> String {
        squashed(
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(dir + file)
            )
        )
    }

    @Test("a master reads mixed only while its edges differ")
    func readingsTrackTheEdges() {
        LocalizationManager.shared.select("en")
        #expect(!GapsBordersGates.outerDiffers(.uniform(10)))
        #expect(!GapsBordersGates.innerDiffers(.uniform(3)))
        #expect(GapsBordersGates.outerDiffers(mixedGaps()))
        #expect(GapsBordersGates.innerDiffers(mixedGaps()))
        #expect(GapsMasterRow.readout(10, mixed: false) == "10 pt")
    }

    @Test("the inheriting row names both masters")
    func summaryNamesBoth() {
        LocalizationManager.shared.select("en")
        var gaps = Gaps.uniform(8)
        gaps.outer.top = 2
        #expect(
            OverrideGapsRow.summary(gaps) == "outer mixed, inner 8 pt"
        )
    }

    @Test("checking the row copies the global gaps exactly")
    func checkingPrefillsFromGlobal() {
        var stored: Gaps? = nil
        let binding = Binding(get: { stored }, set: { stored = $0 })
        overrideToggle(binding, global: mixedGaps()).wrappedValue = true
        #expect(stored == mixedGaps())
        overrideToggle(binding, global: mixedGaps()).wrappedValue = false
        #expect(stored == nil)
    }

    @Test("a floating Space greys the row, a tiling one does not")
    func floatingIsInert() {
        let space = SpaceID("2")
        let key = SettingKey.gaps(.perSpaceOverride)
        let floating = SpacesGates(
            settings: TilingSettings(),
            space: space,
            mode: .floating
        )
        #expect(floating.inertReason(for: key) == .floatingPlacesNone)
        for mode in LayoutMode.allCases where mode != .floating {
            let gates = SpacesGates(
                settings: TilingSettings(),
                space: space,
                mode: mode
            )
            #expect(gates.inertReason(for: key) == nil)
        }
    }

    /// One master row and one comparison for every `Gaps` editor
    /// (gui.md ▸ the gap masters, #1383).
    @Test("the gaps row shares the Gaps & Borders masters")
    func gapsRowSharesTheMasters() throws {
        let row = try Self.source("OverrideGapsRow.swift")
        #expect(row.components(separatedBy: "GapsMasterRow(").count == 3)
        #expect(row.contains("GapsBordersGates.outerDiffers(current)"))
        #expect(row.contains("GapsBordersGates.innerDiffers(current)"))
        #expect(!row.contains("SettingsSlider("))
        #expect(row.contains("overrideToggle($value,global:global)"))
        #expect(row.contains("inheritsFrom:.gapsAndBorders"))
    }

    /// The row sits above the layout rows on every mode, writes
    /// the Space's own gaps over the global ones, and greys
    /// through the area's resolver.
    @Test("the box draws the gaps row first through its gate")
    func boxDrawsTheRow() throws {
        let box = try Self.source("SpaceOverrideRows.swift")
        #expect(box.contains("captionRowgapsRowDivider()modeRows"))
        #expect(
            box.contains(
                Self.squashed(
                    "OverrideGapsRow(value: "
                        + "$model.config.settings.gapsOverride[space], "
                        + "global: g.gapsGlobal)"
                )
            )
        )
        #expect(
            box.contains("gates.inertReason(for:.gaps(.perSpaceOverride))")
        )
        // The answer is drawn: the row greyed, its reason beside it.
        #expect(
            box.contains("row.modifier(GreyOut(active:true,help:sentence))")
        )
        #expect(box.contains("Text(sentence)"))
    }
}
