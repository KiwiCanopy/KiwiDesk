import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let core = makeTestCore(
        configDirectory:
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-focus-wrap-run-\(UUID().uuidString)"
            )
    )
    // Pin the display (tests.md / #531).
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

private func window(_ id: UInt32) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: pid_t(910_000 + id),
        appName: "App\(id)",
        frame: CGRect(x: 0, y: 25, width: 700, height: 875)
    )
}

/// This screen's wrap inside a Stack run that hides windows
/// (#2618): a wrap landing back in the run reaches its far end,
/// hidden or not; one leaving the run lands where the geometric
/// wrap puts it.
@Suite("Focus wrap in a run (#2618)", .serialized)
@MainActor
struct FocusWrapRunTests {
    /// One master and a stack column too short for its members.
    private func stack() throws -> (KiwiCore, RunZone) {
        let core = makeCore()
        for id in UInt32(1)...7 {
            core.state.apply(.windowCreated(window(id)))
        }
        core.execute("set_mode", args: [.string("stack")])
        core.execute("set_min_window_size", args: [.number(300)])
        core.execute("set_focus_wrap", args: [.string("this_screen")])
        let space = try #require(core.state.workspaces.activeSpace)
        core.retile(animated: false)
        let zone = try #require(core.tiler.runCovers[space]?.runs.first)
            .zone
        try #require(zone.vertical)
        return (core, zone)
    }

    private func focus(_ core: KiwiCore, _ id: WindowID) {
        core.state.apply(.windowFocused(id))
        core.retile(animated: false)
    }

    @Test("↑ at the run's top wraps to its hidden last window")
    func upWrapsToTheEnd() throws {
        let (core, zone) = try stack()
        let first = try #require(zone.members.first)
        let last = try #require(zone.members.last)
        focus(core, first)
        try #require(core.runHidden.contains(last))
        #expect(core.navigate([.string("up")], swapping: false).isSuccess)
        #expect(core.state.workspaces.lastFocused == last)
    }

    @Test("↓ at the run's end wraps to its hidden first window")
    func downWrapsToTheStart() throws {
        let (core, zone) = try stack()
        let first = try #require(zone.members.first)
        let last = try #require(zone.members.last)
        focus(core, last)
        try #require(core.runHidden.contains(first))
        #expect(core.navigate([.string("down")], swapping: false).isSuccess)
        #expect(core.state.workspaces.lastFocused == first)
    }

    /// The control: → from the stack column wraps out of the run to
    /// the master on the left, which the run change leaves alone.
    @Test("a wrap leaving the run keeps the geometric target")
    func wrapOutOfTheRunStays() throws {
        let (core, zone) = try stack()
        let tiled = core.state.effectiveTiledMembers(
            of: try #require(core.activeSpace)
        )
        let master = try #require(tiled.first { !zone.members.contains($0) })
        let first = try #require(zone.members.first)
        focus(core, first)
        #expect(core.navigate([.string("right")], swapping: false).isSuccess)
        #expect(core.state.workspaces.lastFocused == master)
    }
}
