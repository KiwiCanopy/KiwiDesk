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

    /// The Space goes with the Desktop, never filed by the fold too.
    @Test("a Space named with a Desktop is not filed at the arrival")
    func spaceRidesTheDesktop() {
        let (core, _) = makeCore()
        defer { teardown() }
        core.state.workspaces.ensureSpace(SpaceID("2"))
        #expect(open(core, space: .string("2")).isSuccess)
        #expect(
            core.launchFollow.quietDesktop(F.app, at: core.wallClock())
                == QuietDesktop(number: 2, space: "2")
        )
        #expect(
            core.launchFollow.quietSpace(F.app, at: core.wallClock()) == nil
        )
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
}
