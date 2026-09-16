import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The "Columns on screen" stepper's arithmetic (#1382), read off
/// the row rather than scanned: what it shows, where ▲ and ▼
/// land, and where ▲ greys. `@MainActor` — the quantities are
/// `View` properties.
@Suite("Slot count row (#1382)")
@MainActor
struct SlotCountRowTests {
    private func row(
        _ size: ScrollSize,
        vertical: Bool = false,
        cap: Int = 6
    ) -> SlotCountRow {
        SlotCountRow(
            size: .constant(size),
            isVertical: vertical,
            cap: cap
        )
    }

    @Test("a whole share shows its count, an off-count share none")
    func countShown() {
        #expect(row(.fraction(0.5)).count == 2)
        #expect(row(.fraction(1.0 / 3)).count == 3)
        #expect(row(.fraction(0.95)).count == nil)
        // Auto is the orientation's 95%: not a whole count.
        #expect(row(.auto).count == nil)
        #expect(row(.points(400)).count == nil)
    }

    @Test("▲ and ▼ step the count, and land on ceil / floor from —")
    func steps() {
        #expect(row(.fraction(1.0 / 3)).up == 4)
        #expect(row(.fraction(1.0 / 3)).down == 2)
        // From the shipped 95%: ▲ is the first whole count above
        // (2), ▼ the first below (1) — never "nearest", which
        // would send both to the same place.
        #expect(row(.fraction(0.95)).up == 2)
        #expect(row(.fraction(0.95)).down == 1)
        #expect(row(.auto).up == 2)
        // 0.3 sits between 3 and 4.
        #expect(row(.fraction(0.3)).up == 4)
        #expect(row(.fraction(0.3)).down == 3)
    }

    @Test("▲ greys at the cap and ▼ at one")
    func bounds() {
        #expect(row(.fraction(1.0 / 6), cap: 6).up == nil)
        #expect(row(.fraction(1.0 / 5), cap: 6).up == 6)
        #expect(row(.fraction(1), cap: 6).down == nil)
        #expect(row(.fraction(0.5), cap: 1).up == nil)
        // An off-count share above the cap greys ▲ too.
        #expect(row(.fraction(0.15), cap: 6).up == nil)
        #expect(row(.fraction(0.15), cap: 6).down == 6)
    }

    @Test("points has no count to step")
    func pointsIsInert() {
        #expect(row(.points(400)).up == nil)
        #expect(row(.points(400)).down == nil)
    }

    @Test("the write lands the count's share in the binding")
    func writeLands() {
        var stored = ScrollSize.fraction(0.95)
        let bound = SlotCountRow(
            size: Binding(get: { stored }, set: { stored = $0 }),
            isVertical: false,
            cap: 6
        )
        bound.write(3)
        #expect(stored == .fraction(ScrollSize.share(of: 3)))
        #expect(ScrollSize.count(of: ScrollSize.share(of: 3)) == 3)
        bound.write(1)
        #expect(stored == .fraction(1))
    }

    @Test("a typed entry is an integer clamped to the cap")
    func typedEntry() {
        #expect(SlotCountRow.typed("3", cap: 6) == 3)
        #expect(SlotCountRow.typed("99", cap: 6) == 6)
        #expect(SlotCountRow.typed("0", cap: 6) == 1)
        #expect(SlotCountRow.typed("1/3", cap: 6) == nil)
        #expect(SlotCountRow.typed("2.5", cap: 6) == nil)
        #expect(SlotCountRow.typed("", cap: 6) == nil)
    }

    @Test("the arrows step up and down; a blur commits only an edit")
    func arrowsAndCommitWiring() throws {
        let source = try SourceScan.stripComments(
            String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Common/"
                            + "SlotCountRow.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(source.occurrences(of: "onIncrement: up.map") == 1)
        #expect(source.occurrences(of: "onDecrement: down.map") == 1)
        // Only text the store did not seed reaches it on a blur.
        #expect(
            source.occurrences(of: "if text != seeded, let n = Self.typed(")
                == 1
        )
    }

    @Test("the hosts hand the row the space whose screen bounds ▲")
    func hostsNameTheirSpace() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        // The row asks the model itself, once, with the space its
        // host named (the parameter has no default).
        let rows = try SourceScan.stripComments(
            String(
                contentsOf: root.appendingPathComponent(
                    "Components/Common/SlotSizeRows.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(
            rows.occurrences(of: "model.scrollingColumnCap(for: space)")
                == 1
        )
        // The count row is mounted, once, handed that cap.
        #expect(rows.occurrences(of: "SlotCountRow(") == 1)
        #expect(
            rows.occurrences(of: "cap: model.scrollingColumnCap(for: space)")
                == 1
        )
        // No host spells the no-screen edge for itself.
        for file in try SourceScan.swiftSources(under: root) {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                text.occurrences(of: "cap: ScrollSize.countCeiling") == 0,
                "\(file.lastPathComponent)"
            )
        }
    }
}

/// One percent formatter (#1382): the wire's spelling, shared by
/// the readouts, the pill and the inherited-value pill — so the
/// card never shows a number the count row or a chip refuses.
@Suite("Percent formatter (#1382)")
@MainActor
struct PercentFormatterTests {
    @Test("the readout is the wire spelling")
    func format() {
        #expect(SettingsValueReadout.percentDigits(0.5) == "50")
        #expect(SettingsValueReadout.percentDigits(1.0 / 3) == "33.33")
        #expect(SettingsValueReadout.percentDigits(0.29) == "29")
        #expect(SettingsValueReadout.percentDigits(0.95) == "95")
        #expect(SettingsValueReadout.percentDigits(2.0 / 3) == "66.67")
        #expect(SettingsValueReadout.percentDigits(1) == "100")
        for fraction in [0.5, 1.0 / 3, 0.29, 1.0 / 7] {
            #expect(
                SettingsValueReadout.percentDigits(fraction) + "%"
                    == ScrollSize.percentString(fraction)
            )
        }
    }

    @Test("the readouts route through the one formatter")
    func routed() throws {
        LocalizationManager.shared.select("en")
        #expect(SettingsValueReadout.percent(1.0 / 3) == "33.33%")
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/Components")
        for name in [
            "Common/SettingsRows.swift", "Common/SlotSizeRows.swift",
            "SpaceOverrides/OverrideControls.swift",
        ] {
            let text = try SourceScan.stripComments(
                String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
            #expect(
                text.occurrences(of: "SettingsValueReadout.percent(") >= 1,
                "\(name)"
            )
            // No hand-spelled percent string beside it.
            #expect(text.occurrences(of: ")%\"") == 0, "\(name)")
        }
        // And the split rows mount the chips, once.
        let rows = try SourceScan.stripComments(
            String(
                contentsOf: root.appendingPathComponent(
                    "Common/SettingsRows.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(rows.occurrences(of: "FractionChips(") == 1)
    }

    @Test("what the readout shows, the count row reads back")
    func readoutRoundTrips() {
        for n in 1...20 {
            let shown = SettingsValueReadout.percentDigits(1 / Double(n))
            let typed = (Double(shown) ?? 0) / 100
            #expect(ScrollSize.count(of: typed) == n)
        }
    }
}

/// The split rows' fraction chips (#1382): pressed exactly where
/// the stored share IS the chip's at the wire's precision.
@Suite("Fraction chips (#1382)")
struct FractionChipsTests {
    @Test("the five shares, in reading order")
    func shares() {
        let glyphs = FractionChips.shares.map(\.glyph)
        #expect(glyphs == ["¼", "⅓", "½", "⅔", "¾"])
        let values = FractionChips.shares.map(\.value)
        let expected: [Double] = [0.25, 1.0 / 3, 0.5, 2.0 / 3, 0.75]
        #expect(values == expected)
    }

    @Test("a chip is pressed only where the share reads as it")
    func pressed() {
        #expect(FractionChips.matches(0.5, 0.5))
        #expect(FractionChips.matches(0.3333, 1.0 / 3))
        #expect(!FractionChips.matches(0.34, 1.0 / 3))
        #expect(!FractionChips.matches(0.52, 0.5))
    }
}
