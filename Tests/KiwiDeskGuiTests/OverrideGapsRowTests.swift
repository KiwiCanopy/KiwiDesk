import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A Space's own gaps row (#1775): its readings, its prefill and
/// its place in the overrides box.
@MainActor
@Suite("Per-Space gaps override row (#1775)")
struct OverrideGapsRowTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func mixedGaps() -> Gaps {
        var gaps = Gaps.uniform(10)
        gaps.outer.left = 4
        gaps.inner.vertical = 6
        return gaps
    }

    @Test("a master reads mixed only while its edges differ")
    func readingsTrackTheEdges() {
        LocalizationManager.shared.select("en")
        let even = OverrideGapsRow.outerReading(.uniform(10))
        #expect(even == .init(value: 10, mixed: false))
        #expect(even.text == "10 pt")
        let gaps = mixedGaps()
        #expect(OverrideGapsRow.outerReading(gaps).mixed)
        #expect(OverrideGapsRow.innerReading(gaps).mixed)
        #expect(!OverrideGapsRow.innerReading(.uniform(3)).mixed)
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
        let global = mixedGaps()
        overrideToggle(binding, global: global).wrappedValue = true
        #expect(stored == global)
        overrideToggle(binding, global: global).wrappedValue = false
        #expect(stored == nil)
    }

    /// The row sits above the layout rows on every mode, and the
    /// Floating arm greys it rather than dropping it.
    @Test("the box draws the gaps row first, greyed on Floating")
    func boxDrawsTheRow() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/SpaceOverrides/"
                    + "SpaceOverrideRows.swift"
            )
        )
        let order = "captionRow gapsRow Divider() modeRows"
        #expect(
            Self.squashed(source).contains(Self.squashed(order))
        )
        #expect(
            Self.squashed(source).contains(
                Self.squashed(
                    "value: $model.config.settings.gapsOverride[space]"
                )
            )
        )
        #expect(
            Self.squashed(source).contains(
                Self.squashed(
                    "row.modifier(GreyOut(active: true, "
                        + "help: Self.floatingGaps))"
                )
            )
        )
    }

    private static func squashed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }
}
