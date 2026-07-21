import Foundation
import Testing

@testable import KiwiDeskCore

/// #431: the App Bar marks a tiled-sticky traveler focused via the
/// system frontmost (`lastFocused`), since a traveler can never be
/// the active space's membership-guarded `focused` slot.
@MainActor
@Suite("App bar sticky focus", .serialized)
struct AppBarStickyFocusTests {

    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: directory)
    }

    private func makeWindow(
        _ id: UInt32,
        isSticky: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            title: "Title",
            isSticky: isSticky
        )
    }

    /// space1 (active) holds locals 1...2; a sticky window homes on
    /// space2 and so travels into space1's row.
    private func seed(_ core: KiwiCore) {
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...2 {
            core.state.windows.upsert(makeWindow(id))
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.windows.upsert(makeWindow(50, isSticky: true))
        core.state.workspaces.add(WindowID(50), to: "2")
    }

    @Test("A frontmost traveler is the active space's bar focus")
    func travelerIsBarFocused() throws {
        let core = makeCore()
        seed(core)
        core.state.workspaces.focus(WindowID(1), in: "1")
        // Focusing the traveler lands on its HOME space and sets
        // the system focus, but never touches space1's slot.
        core.state.workspaces.focus(WindowID(50), in: "2")
        let s1 = try #require(core.state.workspaces["1"])
        #expect(s1.focused == WindowID(1))
        #expect(core.appBarFocused(of: s1) == WindowID(50))
    }

    @Test("A local focus keeps the space's own bar focus")
    func localStaysOwnFocus() throws {
        let core = makeCore()
        seed(core)
        core.state.workspaces.focus(WindowID(50), in: "2")
        core.state.workspaces.focus(WindowID(2), in: "1")
        let s1 = try #require(core.state.workspaces["1"])
        #expect(core.appBarFocused(of: s1) == WindowID(2))
    }

    @Test("An inactive space keeps its own remembered focus")
    func inactiveKeepsOwnFocus() throws {
        let core = makeCore()
        seed(core)
        // space2 owns the sticky as a real member; make it that
        // space's remembered focus, then focus onto active space1.
        core.state.workspaces.focus(WindowID(50), in: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
        let s2 = try #require(core.state.workspaces["2"])
        // `lastFocused` is now window 1 on the active space, but
        // the inactive space's bar must still read its own slot.
        #expect(core.appBarFocused(of: s2) == WindowID(50))
    }
}
