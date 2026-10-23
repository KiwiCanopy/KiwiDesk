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
                "kiwidesk-focus-wrap-\(UUID().uuidString)"
            )
    )
    // Pin the display (tests.md / #531).
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

private func window(_ id: UInt32, x: CGFloat = 0) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: pid_t(900_000 + id),
        appName: "App\(id)",
        frame: CGRect(x: x, y: 25, width: 700, height: 875)
    )
}

/// One focus-wrap setting for every layout (#2493): Off stops at
/// the last window, This screen wraps within the screen — BSP,
/// Stack and Grid geometrically — and All screens continues onto
/// the neighbouring screen, wrapping this one where none has a
/// window. One BSP Space of two windows side by side.
@Suite("Focus wrap (#2493)", .serialized)
@MainActor
struct FocusWrapTests {
    private func pair() -> KiwiCore {
        let core = makeCore()
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(.windowCreated(window(2, x: 740)))
        core.state.apply(.windowFocused(WindowID(2)))
        return core
    }

    private func focused(_ core: KiwiCore) -> WindowID? {
        core.state.workspaces.lastFocused
    }

    @Test("All screens is the default")
    func defaultMode() {
        #expect(FocusWrap.defaultMode == .allScreens)
        #expect(makeCore().focusWrap.mode == .allScreens)
    }

    @Test("Off stops at the last window with the dead end")
    func offStops() {
        let core = pair()
        core.execute("set_focus_wrap", args: [.string("off")])
        let response = core.navigate([.string("right")], swapping: false)
        #expect(!response.isSuccess)
        #expect(focused(core) == WindowID(2))
    }

    @Test("This screen wraps BSP to the window at the far edge")
    func thisScreenWrapsGeometrically() {
        let core = pair()
        core.execute("set_focus_wrap", args: [.string("this_screen")])
        #expect(core.navigate([.string("right")], swapping: false).isSuccess)
        #expect(focused(core) == WindowID(1))
        #expect(core.navigate([.string("left")], swapping: false).isSuccess)
        #expect(focused(core) == WindowID(2))
    }

    @Test("All screens with one screen wraps like This screen")
    func oneScreenAllScreensWraps() {
        let core = pair()
        #expect(core.navigate([.string("right")], swapping: false).isSuccess)
        #expect(focused(core) == WindowID(1))
    }

    @Test("A swap never wraps")
    func swapNeverWraps() {
        let core = pair()
        core.execute("set_focus_wrap", args: [.string("this_screen")])
        #expect(!core.navigate([.string("right")], swapping: true).isSuccess)
    }

    @Test("set_focus_wrap reads its values from the type")
    func verbRefusesUnknown() {
        let core = makeCore()
        #expect(
            !core.execute("set_focus_wrap", args: [.string("wrap")])
                .isSuccess
        )
        for mode in FocusWrap.allCases {
            #expect(
                core.execute("set_focus_wrap", args: [.string(mode.rawValue)])
                    .isSuccess
            )
            #expect(core.focusWrap.mode == mode)
        }
    }

    @Test("a profile's override wins over the base")
    func profileOverrideWins() {
        let core = makeCore()
        core.applyFocusWrap(base: .thisScreen, profile: .off)
        #expect(core.focusWrap.mode == .off)
        core.execute("set_focus_wrap", args: [.string("all_screens")])
        #expect(core.focusWrap.mode == .off)
        core.applyFocusWrap(profile: nil)
        #expect(core.focusWrap.mode == .allScreens)
    }

    @Test("the per-layout verbs retired for set_focus_wrap")
    func layoutVerbsRetired() {
        for layout in ["scroll", "monocle", "track"] {
            #expect(
                APIReference.retired["\(layout).set_wrap_focus"]
                    == .some("set_focus_wrap")
            )
        }
    }

    @Test("the scroll gesture reads All screens as This screen")
    func gestureStaysOnItsScreen() {
        #expect(FocusWrap.allScreens.withinScreen == .thisScreen)
        #expect(FocusWrap.thisScreen.withinScreen == .thisScreen)
        #expect(FocusWrap.off.withinScreen == .off)
    }
}
