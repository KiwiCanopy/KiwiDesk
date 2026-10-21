import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The nets a window-id swap owes beside its membership (#2509):
/// the no-follow latch and move settle for the window that LEFT,
/// the z-order restore a trade into the active Space arms, and
/// the #438 refusal of a sticky window into a pile.
@Suite("swap by window id: latch, settle, restack (#2509)", .serialized)
@MainActor
struct SwapWindowGuardTests {
    private static let one = SpaceID("1")
    private static let two = SpaceID("2")
    private static let three = SpaceID("3")

    /// Space 1 (active) holds `active` windows from 900001, the
    /// last focused; Spaces 2 and 3 hold 900101/900102 and
    /// 900201/900202.
    private func makeCore(
        active: Int = 2,
        bounds: CGRect = CGRect(x: 0, y: 25, width: 1440, height: 875)
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-swapg-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in bounds }
        for index in 0..<active {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(900_001 + index)),
                        pid: 900_001,
                        appName: "A"
                    )
                )
            )
        }
        for (space, base) in [(Self.two, 900_101), (Self.three, 900_201)] {
            for raw in [base, base + 1] {
                core.state.windows.upsert(
                    ManagedWindow(
                        id: WindowID(UInt32(raw)),
                        pid: 900_002,
                        appName: "B"
                    )
                )
                core.state.workspaces.add(WindowID(UInt32(raw)), to: space)
            }
        }
        return core
    }

    /// The focused window LEAVES under `swap_here`: it is latched
    /// against the #482 follow, and the move settle watches for
    /// its app keeping key focus (#463).
    @Test("the window swap_here sends away is latched and settled")
    func departingWindowIsLatched() {
        let core = makeCore()
        let mine = WindowID(900_002)
        #expect(core.focusedWindowID == mine)
        core.execute("swap_here", args: [.number(900_101)])
        #expect(core.state.workspaces.space(of: mine) == Self.two)
        #expect(core.moveLatch.isLatched(mine))
        #expect(core.moveLatch.isLatched(WindowID(900_101)))
        #expect(core.deferred.isScheduled(.moveSettle))
    }

    /// A trade bringing a window into an overflowing scrolling
    /// row arms the restore after its retile; one between two
    /// Spaces nobody shows arms nothing.
    @Test("a trade into an overflowing row arms a restore")
    func tradeArmsTheRestore() throws {
        let core = makeCore(active: 5)
        core.execute("set_mode", args: [.string("1"), .string("scrolling")])
        guard let screen = NSScreen.main else { return }
        core.tiler.animation.animate(
            window: WindowID(999),
            on: screen,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 800, y: 0, width: 100, height: 100)
        )
        try #require(core.tiler.animation.activeCount > 0)
        core.execute(
            "swap",
            args: [.number(900_102), .number(900_201)]
        )
        #expect(!core.pendingZOrderRestore)
        // A swap inside a Space nobody shows (900201 joined it
        // above) restacks nothing, whatever the active row holds.
        core.execute("set_mode", args: [.string("2"), .string("scrolling")])
        core.execute(
            "swap",
            args: [.number(900_101), .number(900_201)]
        )
        #expect(!core.pendingZOrderRestore)
        core.execute("swap_here", args: [.number(900_101)])
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A screen too small for three tiles piles them; a sticky
    /// window is never swapped into that pile.
    @Test("a sticky window is refused a swap into a pile")
    func stickyIntoPileRefused() throws {
        let core = makeCore(
            active: 3,
            bounds: CGRect(x: 0, y: 25, width: 400, height: 300)
        )
        core.state.windows.setSticky(WindowID(900_003), .global)
        let space = try #require(core.activeSpace)
        let frames = core.tiler.calculatedFrames(state: core.state)
        let slots = space.windows.compactMap { id in
            frames[id].map { (id: id, frame: $0) }
        }
        let pile = Navigation.pileMates(
            of: WindowID(900_001),
            among: slots
        )
        try #require(!pile.isEmpty)
        let before = space.windows
        core.execute("swap", args: [.number(900_001)])
        #expect(core.state.workspaces[Self.one]?.windows == before)
    }
}
