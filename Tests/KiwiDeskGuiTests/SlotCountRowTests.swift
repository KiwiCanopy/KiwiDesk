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
}

/// One percent formatter (#1382): whole numbers whole, otherwise
/// one decimal, shared by the readouts and the pill.
@Suite("Percent formatter (#1382)")
@MainActor
struct PercentFormatterTests {
    @Test("whole numbers whole, otherwise one decimal")
    func format() {
        #expect(SettingsValueReadout.percentDigits(0.5) == "50")
        #expect(SettingsValueReadout.percentDigits(1.0 / 3) == "33.3")
        #expect(SettingsValueReadout.percentDigits(0.29) == "29")
        #expect(SettingsValueReadout.percentDigits(0.95) == "95")
        #expect(SettingsValueReadout.percentDigits(2.0 / 3) == "66.7")
        #expect(SettingsValueReadout.percentDigits(1) == "100")
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
