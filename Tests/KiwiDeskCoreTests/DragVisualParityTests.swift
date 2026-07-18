import Testing

@testable import KiwiDeskCore

/// `DragVisual.CodingKeys` became `CaseIterable` for the palette
/// color-key reflection (#375). Guard the key list against the
/// stored fields the same way the other bar styles are guarded, so
/// a new field can't silently miss its coding key (or the palette
/// surface).
@Suite("Drag visual coding parity")
struct DragVisualParityTests {
    @Test("Every CodingKey matches a stored field")
    func keyParity() {
        #expect(
            keyStrings(DragVisual.CodingKeys.allCases)
                == Set(
                    fieldNames(DragVisual.ghostDefault)
                        .map(snakeCased)
                )
        )
    }
}
