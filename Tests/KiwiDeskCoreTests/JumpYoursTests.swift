import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's current window (#3168): the snapshot names the window
/// the list leaves out — the focus, while its app is in front — and
/// gives its app the strip's first tile.
@Suite("KiwiHub snapshot names your window (#3168)")
@MainActor
struct JumpYoursTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for space: SpaceID in ["1", "2"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        return core
    }

    private func track(_ core: KiwiCore, _ id: UInt32, in space: SpaceID) {
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(id),
                pid: 900_001,
                appName: "App",
                title: "W\(id)"
            )
        )
        core.state.workspaces.add(WindowID(id), to: space)
    }

    @Test("the window the list leaves out is yours, as a row draws it")
    func namesTheWindowYouAreIn() throws {
        let core = makeCore()
        track(core, 1, in: "1")
        track(core, 2, in: "1")
        track(core, 3, in: "2")
        core.state.workspaces.focus(WindowID(2), in: "1")
        core.frontmostPIDProvider = { 900_001 }
        let yours = try #require(core.jumpSnapshot().yours)
        #expect(yours.target == .window(WindowID(2)))
        #expect(yours.title == "W2")
        #expect(yours.space == "1")
        #expect(yours.swapBlock == .yours)
        #expect(
            !core.jumpSnapshot().entries.contains {
                $0.target == .window(WindowID(2))
            }
        )
    }

    /// Your app keeps its tile with no other window listed, as ⌘⇥
    /// lists the app in front (#3168).
    @Test("your app has a tile though the list leaves your window out")
    func yourAppHasATile() {
        let core = makeCore()
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(1),
                pid: 900_002,
                appName: "Mine",
                title: "W1"
            )
        )
        core.state.workspaces.add(WindowID(1), to: "1")
        track(core, 2, in: "1")
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.frontmostPIDProvider = { 900_002 }
        // Another app used more recently still comes after yours.
        core.state.stampAppRecency(900_001)
        let snapshot = core.jumpSnapshot()
        #expect(snapshot.yours?.pid == 900_002)
        #expect(!snapshot.entries.contains { $0.pid == 900_002 })
        #expect(snapshot.apps.map(\.pid) == [900_002, 900_001])
    }

    /// A focus whose app is not in front stays a row, so it is not
    /// drawn as yours as well (the 2026-10-12 ruling's own case).
    @Test("a focus under another app is a row, not yours")
    func staleFocusIsNoCurrentWindow() {
        let core = makeCore()
        track(core, 1, in: "1")
        track(core, 2, in: "1")
        core.state.workspaces.focus(WindowID(2), in: "1")
        core.frontmostPIDProvider = { 999 }
        let snapshot = core.jumpSnapshot()
        #expect(snapshot.yours == nil)
        #expect(
            snapshot.entries.contains { $0.target == .window(WindowID(2)) }
        )
    }

    /// Where the focus and the window Swap here trades with differ
    /// — KiwiHub opened on a Space whose own focus is another — no
    /// greyed row names one of them while ⌥↩ acts on the other.
    @Test("a swap partner apart from the focus draws no current window")
    func partnerApartFromFocus() {
        let core = makeCore()
        track(core, 1, in: "1")
        track(core, 3, in: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.state.workspaces.focus(WindowID(3), in: "2")
        core.state.workspaces.activate("1")
        core.frontmostPIDProvider = { 900_001 }
        let snapshot = core.jumpSnapshot()
        #expect(core.jumpSwapPartner(in: "1") == WindowID(1))
        #expect(core.jumpFocusedWindow() == WindowID(3))
        #expect(snapshot.yours == nil)
        let partner = snapshot.entries.first {
            $0.target == .window(WindowID(1))
        }
        #expect(partner?.swapBlock == .yours)
    }

    @Test("with no window tracked there is none")
    func noWindowNoLine() {
        let core = makeCore()
        #expect(core.jumpSnapshot().yours == nil)
    }
}
