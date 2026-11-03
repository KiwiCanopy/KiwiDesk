import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A run size (#2709) follows its window through the Space's
/// membership doors: a window leaving takes its entry with it, and
/// a trade hands the entry to the window taking the slot.
@Suite("Run size membership (#2709)")
struct RunSizeMembershipTests {
    private let a = WindowID(1)
    private let b = WindowID(2)
    private let c = WindowID(3)

    private func space() -> Space {
        var space = Space(id: SpaceID("1"), windows: [a, b])
        space.runSizes = [a: 0.6]
        return space
    }

    @Test("A window leaving drops its run size")
    func removeDropsTheSize() {
        var space = space()
        space.remove(a)
        #expect(space.runSizes.isEmpty)
    }

    @Test("A trade hands the run size to the incoming window")
    func tradeCarriesTheSize() {
        var space = space()
        space.replace(a, with: c)
        #expect(space.runSizes == [c: 0.6])
    }
}
