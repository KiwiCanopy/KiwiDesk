import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Bar peek's row does what clicking that window's App Bar
/// item does (#1946): it focuses the window where the bar draws it.
/// A tiled-sticky traveler is the case that tells the two apart —
/// its home Space is another, and deriving the row's Space from
/// state focuses nothing; a window on the Space another screen
/// shows is the case where that derivation switches.
@MainActor
@Suite("Bar peek App Bar rows", .serialized)
struct BarPeekAppBarRowTests {
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        // Space 1 (active) holds 1 and 2; sticky 50 homes on Space 2
        // and so travels into Space 1's App Bar row.
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        for id: UInt32 in [1, 2, 50] {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(id),
                    pid: 100,
                    appName: "App",
                    title: "Title \(id)",
                    stickyScope: id == 50 ? .global : .none
                )
            )
            core.state.workspaces.add(WindowID(id), to: id == 50 ? "2" : "1")
        }
        core.state.workspaces.focus(WindowID(1), in: "1")
        return core
    }

    @Test("An App Bar row focuses a traveler where its item would")
    func travelerRowActsAsItsItem() {
        let viaRow = makeCore()
        let viaItem = makeCore()
        // The App Bar's anchor carries no Space: its peek's pick.
        viaRow.shelves.peek.pick(WindowID(50), nil)
        viaItem.appBars.onSelect(WindowID(50))
        #expect(viaRow.activeSpace?.id == SpaceID("1"), "no switch away")
        #expect(viaRow.activeSpace?.id == viaItem.activeSpace?.id)
        #expect(
            viaRow.state.workspaces.lastFocused
                == viaItem.state.workspaces.lastFocused
        )
    }

    /// Space 1 active on one screen; Space 2 shown on the other,
    /// holding 60, which that screen's App Bar draws. Deriving the
    /// row's Space from state finds Space 2, where 60 IS a member,
    /// and switches to it; its item focuses it in place.
    private func makeTwoScreenCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.assign("2", to: DisplayID(2))
        for (id, space): (UInt32, SpaceID) in [(1, "1"), (60, "2")] {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(id),
                    pid: 100,
                    appName: "App",
                    title: "Title \(id)"
                )
            )
            core.state.workspaces.add(WindowID(id), to: space)
        }
        core.state.workspaces.activate("2")
        core.state.workspaces.activate("1")
        core.state.workspaces.focus(WindowID(1), in: "1")
        return core
    }

    @Test("An App Bar row on the other screen focuses without a switch")
    func otherScreenRowFocusesInPlace() throws {
        let viaRow = makeTwoScreenCore()
        let viaItem = makeTwoScreenCore()
        try #require(
            viaRow.state.workspaces.activeSpace(on: DisplayID(2))
                == SpaceID("2")
        )
        viaRow.shelves.peek.pick(WindowID(60), nil)
        viaItem.appBars.onSelect(WindowID(60))
        #expect(viaItem.activeSpace?.id == SpaceID("1"))
        #expect(viaRow.activeSpace?.id == SpaceID("1"), "no switch")
        #expect(
            viaRow.state.workspaces.lastFocused
                == viaItem.state.workspaces.lastFocused
        )
    }
}
