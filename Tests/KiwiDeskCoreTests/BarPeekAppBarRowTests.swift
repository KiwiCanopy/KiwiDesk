import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Bar peek's row does what clicking that window's App Bar
/// item does (#1946): it focuses the window where the bar draws it.
/// A tiled-sticky traveler is the case that tells the two apart —
/// its home Space is another, and deriving the row's Space from
/// state would switch away to it.
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
}
