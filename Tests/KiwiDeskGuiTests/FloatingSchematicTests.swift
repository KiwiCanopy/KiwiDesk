import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Floating's schematic (#828), which drew an `EmptyView` until
/// this change — a blank tile in the tour's space rows and in
/// Settings' own "Choose a layout" strip.
///
/// Split from `LayoutSchematicCountTests`, which was at the §2.1
/// ceiling: the count sweep there holds that every schematic
/// DECLARES a window count, and this holds what Floating's does
/// with it.
@Suite("Floating schematic")
@MainActor
struct FloatingSchematicTests {
    /// Floating's own count-derived quantity, asserted directly
    /// rather than left to the scan above — a schematic that
    /// takes the count and draws a constant satisfies every
    /// substring a scan can look for while answering nothing.
    ///
    /// Its cap is 3: past that the offset fan marches off the
    /// canvas, which is `MonocleSchematic.depth`'s argument at a
    /// different number.
    @Test("Floating draws a window per count, capped at three")
    func floatingDrawsPerCount() {
        for count in LayoutSchematic.windowCountRange {
            let drawn = FloatingSchematic(windows: count).drawn
            #expect(drawn == min(count, 3))
            #expect(drawn >= 1)
        }
        // Vacuity: the cap is only a cap if the range crosses it.
        #expect(LayoutSchematic.windowCountRange.lowerBound < 3)
        #expect(LayoutSchematic.windowCountRange.upperBound > 3)
    }
}
