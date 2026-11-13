import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The speed strip fits (#3254 ▸ Ruling amendment 2026-11-13): five
/// speeds outgrow the label column's row in several catalogs, so the
/// row stacks its strip under its label at every band, and the strip
/// at its natural width fits the narrowest card interior in every
/// shipped catalog. It cannot see a padding added beside the two
/// insets read here, nor Simple's own card widths.
///
/// Main-actor spend: one hosted strip per catalog, measured once.
@Suite("Animation speed strip fits (#3254)")
@MainActor
struct AnimationSpeedRowFitTests {
    @Test("the strip fits the narrowest card in every catalog")
    func stripFits() {
        defer { LocalizationManager.shared.select("en") }
        let codes = LocaleCatalog.availableLocales() + ["en"]
        #expect(codes.count >= 11)
        let interior =
            SettingsWidthClass.minimum - SettingsMetrics.paneInset * 2
            - SettingsMetrics.sectionPlateInset * 2
        for code in codes {
            LocalizationManager.shared.select(code)
            var pick: AnimationPacePreset? = .medium
            let strip = SegmentedPicker(
                spokenLabel: AnimationSpeedRow.label,
                selection: Binding(get: { pick }, set: { pick = $0 }),
                options: AnimationPacePreset.allCases.map {
                    (AnimationSpeedRow.title(of: $0), Optional($0))
                }
            )
            let width = NSHostingView(rootView: strip.fixedSize())
                .fittingSize.width
            #expect(width > 200, "\(code) measured nothing")
            #expect(width <= interior, "\(code): \(width) in \(interior)")
        }
    }

    @Test("the row stacks its strip at every band")
    func rowStacks() throws {
        let flat = { (path: String) in
            try SourceScan.strippedSource(
                at: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(path)
            ).filter { !$0.isWhitespace }
        }
        let row = try flat(
            "Sources/KiwiDesk/Settings/Components/Looks/"
                + "AnimationSpeedRow.swift"
        )
        #expect(
            row.contains(
                "SettingsRowShape(alwaysStacks:true){"
                    + "SettingsRowLabel(label:Self.label,help:Self.help)"
                    + "}control:{SegmentedPicker(spokenLabel:Self.label,"
            )
        )
        let shape = try flat(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsRowShape.swift"
        )
        #expect(
            shape.contains(
                "letstacked=width.stacksRows&&!staysInline||alwaysStacks"
            )
        )
    }
}
