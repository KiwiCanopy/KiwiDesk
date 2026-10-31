import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A Simple Space card's picture (#2777 ruling 9). No main actor.
@Suite("Simple Space picture")
struct SimpleSpacePictureTests {
    /// Floating's single window reads as an empty screen on a card,
    /// so its picture draws the whole scatter.
    @Test("Floating's picture draws its scatter")
    func floatingDrawsItsScatter() {
        // From a count below the scatter, so the floor is what
        // answers, not the default count.
        #expect(SimpleSpacePicture.windows(for: .floating, base: 1) >= 3)
        #expect(SimpleSpacePicture.windows(for: .floating) >= 3)
        #expect(
            SimpleSpacePicture.windows(for: .bsp)
                == LayoutSchematic.windowCount(
                    LayoutSchematic.defaultWindowCount,
                    for: .bsp
                )
        )
    }
}
