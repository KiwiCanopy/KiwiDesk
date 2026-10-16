import Testing

@testable import KiwiDesk

/// `ShortcutsReference`'s sections are walked by hand in four
/// places — `isEmpty`, `ShortcutsSheet.filtered`,
/// `ShortcutsSheet.matchCount` and `ShortcutsSheetView.sections` —
/// so a section added to the type passes through the filter
/// unfiltered and out of the count with nothing red (#2246,
/// parity-tests.md). This reds on any stored property it does not
/// name, so the author meets the four sites.
@Suite("ShortcutsReference sections are walked everywhere")
struct ShortcutsReferenceParityTests {
    @Test("every stored property is a known section")
    func storedPropertiesAreKnown() {
        let reference = ShortcutsReference(
            layerName: "",
            controls: [],
            apps: [],
            custom: []
        )
        let names = Mirror(reflecting: reference).children.compactMap(\.label)
        #expect(
            names == [
                "layerName", "controls", "inactive", "unavailable",
                "apps", "custom",
            ],
            Comment(
                rawValue: "a new section must join isEmpty, the filter, "
                    + "the count and the column"
            )
        )
    }
}
