import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `open_in_background(bundle_id, space, desktop)` (#3153 ▸ Ruling):
/// a named Desktop is refused up front where the bridge or the number
/// fails, and each window of the app arriving while its quiet mark
/// stands is sent there through `move_to_desktop`'s own body. Over
/// the #888 fixture (`DesktopMoveNamedWindowTests`' arrangement):
/// Desktop 1 shown and Desktop 2 hidden on the main screen.
///
/// `WMBridge.classResolverOverride` is process-global, hence
/// `.serialized`.
@Suite("open_in_background sends to a named Desktop (#3153)", .serialized)
@MainActor
struct OpenInBackgroundDesktopTests {
    typealias F = OpenInBackgroundTests

    private func makeCore(bridge: Bool = true) -> (KiwiCore, F.Recorder) {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = {
            bridge ? desktopVerbBridgeClasses[$0] : nil
        }
        return F.makeCore()
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func open(
        _ core: KiwiCore,
        space: JSONValue = .null,
        desktop: JSONValue = .number(2)
    ) -> CommandResponse {
        core.execute(
            "open_in_background",
            args: [.string(F.app), space, desktop]
        )
    }

    private func moved() -> [[NSNumber]] {
        DesktopVerbBridge.moves.map { $0.0 }
    }

    @Test("each window of the app is sent to the named Desktop")
    func windowsAreSent() {
        let (core, recorder) = makeCore()
        defer { teardown() }
        #expect(open(core).isSuccess)
        #expect(recorder.opened.map(\.1) == [.background])
        F.arrive(7, bundleID: F.app, on: core)
        F.arrive(8, bundleID: F.app, on: core)
        #expect(
            moved() == [[NSNumber(value: 7)], [NSNumber(value: 8)]]
        )
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("another app's window is not sent")
    func otherAppStays() {
        let (core, _) = makeCore()
        defer { teardown() }
        #expect(open(core).isSuccess)
        F.arrive(7, bundleID: F.other, on: core)
        #expect(moved().isEmpty)
    }

    @Test("no bridge is refused before anything launches")
    func noBridgeRefused() {
        let (core, recorder) = makeCore(bridge: false)
        defer { teardown() }
        let answer = open(core)
        #expect(
            answer.error == "the Desktop bridge is unavailable on this macOS"
        )
        #expect(recorder.opened.isEmpty)
    }

    @Test("an unknown Desktop is refused before anything launches")
    func unknownDesktopRefused() {
        let (core, recorder) = makeCore()
        defer { teardown() }
        let answer = open(core, desktop: .number(9))
        #expect(answer.error == "no Desktop 9")
        #expect(recorder.opened.isEmpty)
    }

    /// The CLI sends only strings: `""` skips the Space ahead of a
    /// Desktop, as `move_to_desktop` reads it.
    @Test("the CLI's empty Space ahead of a Desktop is skipped")
    func cliSkipsTheSpace() {
        let (core, _) = makeCore()
        defer { teardown() }
        #expect(
            open(core, space: .string(""), desktop: .string("2")).isSuccess
        )
        F.arrive(7, bundleID: F.app, on: core)
        #expect(moved() == [[NSNumber(value: 7)]])
    }

    /// The Space rides the move to the hidden Desktop (#1150), and
    /// the fold files it nowhere.
    @Test("a Space named with a Desktop reaches the move")
    func spaceReachesTheMove() {
        let (core, _) = makeCore()
        defer { teardown() }
        var log: [String] = []
        core.onLog = { log.append($0) }
        #expect(open(core, space: .string("mail")).isSuccess)
        #expect(
            core.launchFollow.quietSpace(F.app, at: core.wallClock()) == nil
        )
        F.arrive(7, bundleID: F.app, on: core)
        #expect(moved() == [[NSNumber(value: 7)]])
        #expect(log.contains { $0.contains("will join space mail") })
        #expect(core.state.workspaces[SpaceID("mail")] == nil)
    }

    @Test("a Desktop already showing is refused")
    func shownDesktopRefused() {
        let (core, recorder) = makeCore()
        defer { teardown() }
        let answer = open(core, desktop: .number(1))
        #expect(answer.error?.contains("already showing") == true)
        #expect(recorder.opened.isEmpty)
    }

    /// The window-free half of the Space parse answers at the call.
    @Test("a Space on another screen is refused before anything opens")
    func spaceOffTheScreenRefused() {
        let (core, recorder) = makeCore()
        defer { teardown() }
        for (index, name) in ["A", "B"].enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: name,
                    frame: CGRect(
                        x: CGFloat(index) * 1920,
                        y: 0,
                        width: 1920,
                        height: 1080
                    )
                )
            )
        }
        let answer = open(core, space: .string("mail"))
        #expect(answer.error?.contains("on no screen yet") == true)
        #expect(recorder.opened.isEmpty)
    }

    /// An arrival the door does not read as new is not sent: a
    /// reveal or re-track, and the accepted residue of a create that
    /// lands after its arrival (#2630, #3153 ▸ Ruling).
    @Test("an arrival not yet known to be created is not sent")
    func uncreatedArrivalStays() {
        let (core, _) = makeCore()
        defer { teardown() }
        core.windowCreates.isLive = true
        core.boot.reachedReady = true
        #expect(open(core).isSuccess)
        F.arrive(7, bundleID: F.app, on: core)
        #expect(moved().isEmpty)
        // The control: the same arrival with its create sent on.
        core.windowCreates.noteCreated(WindowID(8), at: core.wallClock())
        F.arrive(8, bundleID: F.app, on: core)
        #expect(moved() == [[NSNumber(value: 8)]])
    }

    @Test("a move refused at the arrival leaves the window here")
    func refusedSendStays() {
        let (core, _) = makeCore()
        defer { teardown() }
        var log: [String] = []
        core.onLog = { log.append($0) }
        let home = core.state.workspaces.activeSpace
        #expect(open(core).isSuccess)
        WMBridge.classResolverOverride = { _ in nil }
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        F.arrive(7, bundleID: F.app, on: core)
        // The arrival retile still runs.
        #expect(meter.snapshot(reset: false).counts.retiles >= 1)
        #expect(core.state.workspaces.space(of: WindowID(7)) == home)
        #expect(log.contains { $0.contains("w7 stays") })
    }

    @Test("a click on the app ends the sending")
    func userTakeEndsSending() {
        let (core, _) = makeCore()
        defer { teardown() }
        #expect(open(core).isSuccess)
        core.lastLeftClick = (core.wallClock(), .zero, nil)
        OpenInBackgroundHoldTests.activate(core)
        F.arrive(7, bundleID: F.app, on: core)
        #expect(moved().isEmpty)
    }

    /// The Desktop came into view between the call and the arrival.
    @Test("a Desktop shown since the call takes no move")
    func shownSinceStays() {
        let (core, _) = makeCore()
        defer { teardown() }
        var log: [String] = []
        core.onLog = { log.append($0) }
        #expect(open(core).isSuccess)
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        F.arrive(7, bundleID: F.app, on: core)
        #expect(moved().isEmpty)
        #expect(log.contains { $0.contains("gone or showing") })
    }
}
