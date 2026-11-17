import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Maximize card's "Show bars at the screen edge" row (#3346)
/// writes `kiwishelf.maximized_visibility`, greys only while the
/// Space Bar, every App Bar and the Pocket are Hidden, its reason a
/// live link drawn outside the grey, and Monocle's "Maximize
/// windows" links to it.
@Suite("Show bars at the screen edge row (#3346)")
struct MaximizeShowBarsRowTests {
    @Test("the row's label is the census and catalog key")
    @MainActor
    func labelIsOneKey() {
        let control = SettingsCatalog.layoutDefaults.maximizeShowBars
        #expect(control.key == "layout_defaults.maximize.show_bars")
        let text = KiwiShelfKey.maximizedVisibility.text
        #expect(text.label == .key(control.key ?? ""))
        #expect(
            text.helpKey == "layout_defaults.maximize.show_bars.help"
        )
        #expect(
            LayoutDefaultsRowOrder.maximize.last
                == .kiwishelf(.maximizedVisibility)
        )
    }

    @Test("the resolver greys only when nothing could reveal")
    func resolverGreysOnNothing() {
        let key = SettingKey.kiwishelf(.maximizedVisibility)
        var settings = TilingSettings()
        // Control: the defaults reveal something, so the row is live.
        #expect(
            LayoutDefaultsGates(settings: settings).inertReason(for: key)
                == nil
        )
        settings.spaceBarStyle.visibility = .hidden
        settings.kiwishelf.pocketVisibility = .hidden
        for mode in LayoutMode.allCases {
            guard let path = TilingSettings.appBarPath(for: mode)
            else { continue }
            settings[keyPath: path].visibility = .hidden
        }
        #expect(
            LayoutDefaultsGates(settings: settings).inertReason(for: key)
                == .nothingRevealsMaximized
        )
        // A reveal never brings the Pocket, so it keeps no row live
        // (#3432); a bar does.
        settings.kiwishelf.pocketVisibility = .always
        #expect(
            LayoutDefaultsGates(settings: settings).inertReason(for: key)
                == .nothingRevealsMaximized
        )
        settings.spaceBarStyle.visibility = .auto
        #expect(
            LayoutDefaultsGates(settings: settings).inertReason(for: key)
                == nil
        )
        #expect(LayoutDefaultsGates.resolved.contains(key))
    }

    /// The arm draws the row; the row asks the resolver, greys the
    /// checkbox alone on its answer and draws the reason's sentence
    /// as a link to KiwiShelf outside it. Scoped to the bodies.
    @Test("the row asks the resolver and draws the reason's link")
    func rowWiring() throws {
        let source = try stripped("Layouts/MaximizeCard.swift")
        let row = try #require(
            SourceScan.declarationBody(
                after: "private func row(_ key: SettingKey)",
                in: source
            )
        )
        #expect(
            squeezed(row).contains(
                "case.kiwishelf(.maximizedVisibility):showBarsRow"
            )
        )
        let body = squeezed(
            try #require(
                SourceScan.declarationBody(
                    after: "private var showBarsRow: some View",
                    in: source
                )
            )
        )
        for needle in [
            ".inertReason(for:.kiwishelf(.maximizedVisibility))",
            "isOn:showsBars,help:Self.showBarsHelp,disabled:reason!=nil)",
            ".searchAnchored(SettingsCatalog.layoutDefaults.maximizeShowBars)",
            "ifletreason{CrossReferenceRow(",
            "prose:LayoutDefaultsGateHelp.sentence(for:reason)",
            "row:SettingsCatalog.bars.kiwishelfCard",
        ] {
            #expect(body.contains(needle), "\(needle)")
        }
        let binding = squeezed(
            try #require(
                SourceScan.declarationBody(
                    after: "private var showsBars: Binding<Bool>",
                    in: source
                )
            )
        )
        #expect(binding.contains("maximizedVisibility==.auto"))
        #expect(binding.contains("$0?.auto:.hidden"))
    }

    @Test("Monocle's Maximize windows links to the row")
    func monocleLinks() throws {
        let source = try stripped("Layouts/LayoutCard+Rows.swift")
        let row = squeezed(
            try #require(
                SourceScan.declarationBody(
                    after: "var monocleMaximizeWindowsRow: some View",
                    in: source
                )
            )
        )
        #expect(row.contains("CrossReferenceRow("))
        #expect(
            row.contains(
                "row:SettingsCatalog.layoutDefaults.maximizeShowBars)"
            )
        )
    }

    /// Both cross-references place their link inside the sentence
    /// (`CrossReferenceRowSlotTests`).
    @Test("both sentences place their link")
    @MainActor
    func prosePlacesItsLink() {
        for prose in [
            LayoutDefaultsGateHelp.nothingRevealsMaximized,
            LayoutHelp.monocleMaximizeBarsProse,
        ] {
            #expect(
                prose.components(separatedBy: CrossReferenceRow.linkSlot)
                    .count == 2,
                "\(prose)"
            )
        }
    }

    private func stripped(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/" + file
            )
        return try SourceScan.strippedSource(at: url)
    }

    private func squeezed(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}
