import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Geometric overflow-pile detection (#172): `Navigation.pileMates`
/// groups a layout's slots into connected components of significant
/// overlap and returns the focused window's cascade-mates. The swap
/// paths (geometric candidate exclusion, track array skip) both
/// build on it.
@Suite("Navigation pile detection (#172)")
struct NavigationPileTests {
    private func id(_ n: UInt32) -> WindowID { WindowID(n) }

    /// A `count`-deep OverlapStack cascade anchored at `origin`
    /// (300 pt windows, 40 pt offset — the real geometry).
    private func cascade(
        _ ids: [WindowID],
        origin: CGPoint = .zero
    ) -> [(id: WindowID, frame: CGRect)] {
        ids.enumerated().map { index, window in
            (
                window,
                CGRect(
                    x: origin.x,
                    y: origin.y + CGFloat(index)
                        * OverlapStack.offset,
                    width: 300,
                    height: 300
                )
            )
        }
    }

    @Test("Disjoint tiled slots form no pile")
    func tiledIsEmpty() {
        // Two side-by-side cells with a gap: no overlap.
        let slots: [(id: WindowID, frame: CGRect)] = [
            (id(1), CGRect(x: 0, y: 0, width: 300, height: 300)),
            (id(2), CGRect(x: 310, y: 0, width: 300, height: 300)),
        ]
        #expect(
            Navigation.pileMates(of: id(1), among: slots).isEmpty
        )
    }

    @Test("A cascade's members are all pile-mates")
    func cascadeMates() {
        let slots = cascade([id(1), id(2), id(3)])
        #expect(
            Navigation.pileMates(of: id(1), among: slots)
                == [id(2), id(3)]
        )
    }

    @Test("Deep piles bind transitively via the chain")
    func deepChain() {
        // Members 0 and 8 (offset 320 > 300) do not overlap
        // directly, but each overlaps its neighbor, so the whole
        // run is one component.
        let ids = (1...9).map { id(UInt32($0)) }
        let slots = cascade(ids)
        let mates = Navigation.pileMates(of: id(1), among: slots)
        #expect(mates == Set(ids.dropFirst()))
    }

    @Test("A separate pile is not the focused window's")
    func separatePiles() {
        // Two disjoint columns, each its own cascade.
        let left = cascade([id(1), id(2)], origin: .zero)
        let right = cascade(
            [id(3), id(4)],
            origin: CGPoint(x: 400, y: 0)
        )
        let mates = Navigation.pileMates(
            of: id(1),
            among: left + right
        )
        // Only the left column's mate, never the right pile.
        #expect(mates == [id(2)])
    }

    @Test("A tiled window beside a pile is excluded")
    func tiledBesidePile() {
        // A fitting cell on the left, a cascade on the right.
        var slots: [(id: WindowID, frame: CGRect)] = [
            (id(1), CGRect(x: 0, y: 0, width: 300, height: 300))
        ]
        slots += cascade(
            [id(2), id(3)],
            origin: CGPoint(x: 400, y: 0)
        )
        // The focused tiled window is in no pile.
        #expect(
            Navigation.pileMates(of: id(1), among: slots).isEmpty
        )
        // The pile members see each other, not the tiled cell.
        #expect(
            Navigation.pileMates(of: id(2), among: slots)
                == [id(3)]
        )
    }

    @Test("A window absent from the slots has no mates")
    func absentWindow() {
        let slots = cascade([id(1), id(2)])
        #expect(
            Navigation.pileMates(of: id(9), among: slots).isEmpty
        )
    }
}

/// `set_swap_skips_cascade` (#172): the global power-user toggle.
@Suite("set_swap_skips_cascade (#172)", .serialized)
@MainActor
struct SwapSkipsCascadeCommandTests {
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-swap-skip-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: directory)
    }

    @Test("Defaults on, and the setter flips it")
    func toggle() {
        let core = makeCore()
        #expect(core.tiler.settings.swapSkipsCascade == true)
        #expect(
            core.execute(
                "set_swap_skips_cascade",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(core.tiler.settings.swapSkipsCascade == false)
    }

    @Test("A non-boolean argument is rejected")
    func rejectsNonBool() {
        let core = makeCore()
        #expect(
            !core.execute(
                "set_swap_skips_cascade",
                args: [.string("yes")]
            ).isSuccess
        )
    }
}
