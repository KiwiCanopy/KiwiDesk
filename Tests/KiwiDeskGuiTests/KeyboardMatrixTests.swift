import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The drawn board. Authored geometry, so what these hold is
/// that the authoring stayed self-consistent — a duplicated key
/// code or a row that lost its width is invisible on screen
/// until someone counts.
@Suite("Keyboard preview matrix")
struct KeyboardMatrixTests {

    @Test(
        "Every board draws each key code at most once",
        arguments: [
            KeyboardMatrix.PhysicalType.ansi,
            .iso,
            .jis,
        ]
    )
    func noCodeIsDrawnTwice(
        type: KeyboardMatrix.PhysicalType
    ) {
        let codes = KeyboardMatrix.rows(for: type)
            .flatMap { $0 }
            .compactMap(\.code)
        #expect(Set(codes).count == codes.count)
    }

    /// The macOS ISO quirk, caught on a German board at the
    /// panel's first sitting (owner, 2026-08-10). Codes 50 and
    /// 10 SWAP physical position between the two boards: on ANSI
    /// 50 is the key left of `1`; on ISO that place belongs to
    /// 10 and 50 moves down beside the left shift. Reusing the
    /// ANSI order for ISO draws both keys with the correct glyph
    /// in the wrong place, which no glyph or count test can see.
    @Test("ISO swaps the two odd keys against ANSI")
    func isoSwapsGraveAndSection() {
        func firstCode(
            _ type: KeyboardMatrix.PhysicalType
        ) -> UInt32? {
            KeyboardMatrix.rows(for: type).first?
                .compactMap(\.code).first
        }
        func bottomLetterRowCodes(
            _ type: KeyboardMatrix.PhysicalType
        ) -> [UInt32] {
            // The row carrying Z (6) and the comma (43).
            KeyboardMatrix.rows(for: type)
                .map { $0.compactMap(\.code) }
                .first { $0.contains(6) && $0.contains(43) } ?? []
        }
        #expect(firstCode(.ansi) == 50)
        #expect(firstCode(.iso) == 10)
        #expect(!bottomLetterRowCodes(.ansi).contains(50))
        #expect(bottomLetterRowCodes(.iso).first == 50)
    }

    @Test("ISO draws the key ANSI does not have")
    func isoAddsItsOwnKey() {
        let ansi = KeyboardMatrix.drawnCodes(for: .ansi)
        let iso = KeyboardMatrix.drawnCodes(for: .iso)
        #expect(!ansi.contains(10))
        #expect(iso.contains(10))
        #expect(iso.count == ansi.count + 1)
    }

    @Test("The two boards are the same width, row for row")
    func rowsKeepOneWidth() {
        for type in [
            KeyboardMatrix.PhysicalType.ansi, .iso,
        ] {
            let widths = KeyboardMatrix.rows(for: type).map {
                $0.reduce(0) { $0 + $1.units }
            }
            #expect(Set(widths).count == 1, "\(type): \(widths)")
        }
    }

    /// BOTH boards, which is the point: the ISO board draws code
    /// 10, and while `KeyCombo.keyCodes` had no entry for it that
    /// key rendered as "free" on every ISO keyboard while being
    /// unbindable — `parse` could never produce it. A key the
    /// board invites you to bind must be one the app can bind.
    @Test(
        "Every drawn code is one the app can bind",
        arguments: [
            KeyboardMatrix.PhysicalType.ansi, .iso, .jis,
        ]
    )
    func drawnCodesAreRealKeys(
        type: KeyboardMatrix.PhysicalType
    ) {
        let bindable = Set(KeyCombo.keyCodes.values)
        let drawn = KeyboardMatrix.drawnCodes(for: type)
        #expect(drawn.subtracting(bindable).isEmpty)
    }

    @Test("The free tally counts drawn keys, not alias entries")
    func drawnCodesDeduplicateAliases() {
        // `keyCodes` collapses aliases onto one code, so its
        // count overstates the keyboard.
        #expect(
            KeyCombo.keyCodes.count
                > Set(KeyCombo.keyCodes.values).count
        )
        let drawn = KeyboardMatrix.drawnCodes(for: .ansi)
        #expect(drawn.count < KeyCombo.keyCodes.count)
    }
}
