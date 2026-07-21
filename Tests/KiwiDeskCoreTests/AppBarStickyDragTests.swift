import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

/// #414 v2: the App Bar lists injected tiled-sticky travelers,
/// but its drag reorder writes back ONLY the space's own array
/// — a traveler must never overwrite a local slot.
@MainActor
@Suite("App bar drag with sticky travelers", .serialized)
struct AppBarStickyDragTests {

    /// Scrolling space 1 with locals 1...3; tiled-sticky 4
    /// homed on space 2 (injected at index 0 on space 1).
    private func makeTravelerCore() -> KiwiCore {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        for (index, name) in ["A", "B", "C"].enumerated() {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index + 1)),
                        pid: 1,
                        appName: name
                    )
                )
            )
        }
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(4),
                pid: 1,
                appName: "D",
                isSticky: true
            )
        )
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.add(WindowID(4), to: SpaceID(2))
        return core
    }

    @Test("Reordering past a traveler drops no local window")
    func reorderPastTraveler() throws {
        let core = makeTravelerCore()
        let space = try #require(core.activeSpace)
        // The bar lists the traveler at its injected slot...
        #expect(
            core.state.effectiveTiledMembers(
                of: space,
                activeSpace: space.id
            ) == [WindowID(4), WindowID(1), WindowID(2), WindowID(3)]
        )
        // ...but dragging local A (bar slot 1) to the end
        // rewrites only the local array: every local survives,
        // the traveler stays a non-member.
        core.moveBarItem(space: SpaceID(1), from: 1, to: 3)
        #expect(
            core.activeSpace?.windows
                == [WindowID(2), WindowID(3), WindowID(1)]
        )
    }

    @Test("Dragging the traveler itself reorders nothing")
    func travelerDragIsNoop() throws {
        let core = makeTravelerCore()
        core.moveBarItem(space: SpaceID(1), from: 0, to: 2)
        // Non-home reorder is a v2 non-goal: the local order is
        // untouched and no window is lost.
        #expect(
            core.activeSpace?.windows
                == [WindowID(1), WindowID(2), WindowID(3)]
        )
        #expect(
            core.state.workspaces[SpaceID(2)]?.windows
                == [WindowID(4)]
        )
    }
}
