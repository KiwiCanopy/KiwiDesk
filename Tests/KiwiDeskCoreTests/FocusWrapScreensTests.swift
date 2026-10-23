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
                "kiwidesk-focus-wrap-screens-\(UUID().uuidString)"
            )
    )
    // Pin the display (tests.md / #531): the main screen's slots.
    core.tiler.visibleBounds = { _ in KiwiCore.mainFrame }
    return core
}

@MainActor
extension KiwiCore {
    fileprivate static let mainFrame = CGRect(
        x: 0,
        y: 25,
        width: 1440,
        height: 875
    )
}

private func window(
    _ id: UInt32,
    x: CGFloat,
    width: CGFloat = 700
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: pid_t(900_000 + id),
        appName: "App\(id)",
        frame: CGRect(x: x, y: 25, width: width, height: 875)
    )
}

/// All screens (#2493) across two screens: a screen on the left no
/// `NSScreen` backs, holding Space 1, and the host's main screen on
/// its right, holding Spaces 2 and 3. The landing resolves the main
/// screen's slots, so a screenless runner skips.
@Suite("Focus wrap across screens (#2493)", .serialized)
@MainActor
struct FocusWrapScreensTests {
    private let left = DisplayID(9_999)
    private static let leftFrame = CGRect(
        x: -1440,
        y: 25,
        width: 1440,
        height: 875
    )

    private func twoScreens(emptyMain: Bool = false) -> KiwiCore? {
        guard let main = ScreenList.all.first?.kiwiDisplayID
        else { return nil }
        let core = makeCore()
        core.tiler.displayFrames = {
            [(self.left, Self.leftFrame), (main, KiwiCore.mainFrame)]
        }
        core.state.workspaces.assign(SpaceID("1"), to: left)
        core.state.workspaces.assign(SpaceID("2"), to: main)
        core.state.workspaces.assign(SpaceID("3"), to: main)
        let shownOnMain = emptyMain ? SpaceID("3") : SpaceID("2")
        core.state.workspaces.activate(SpaceID("2"))
        core.state.apply(.windowCreated(window(21, x: 0)))
        core.state.apply(.windowCreated(window(22, x: 740)))
        core.state.workspaces.activate(shownOnMain)
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(11, x: -1440)))
        core.state.apply(.windowCreated(window(12, x: -700)))
        core.state.apply(.windowFocused(WindowID(12)))
        return core
    }

    private func right(_ core: KiwiCore) -> Bool {
        core.navigate([.string("right")], swapping: false).isSuccess
    }

    @Test("past the last window focus lands on the next screen")
    func hopsToTheNextScreen() {
        guard let core = twoScreens() else { return }
        #expect(right(core))
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        // The window nearest the entering edge: the left one.
        #expect(core.state.workspaces.lastFocused == WindowID(21))
    }

    @Test("past the last screen focus wraps back to the first")
    func wrapsBackAround() {
        guard let core = twoScreens() else { return }
        core.state.apply(.windowFocused(WindowID(12)))
        #expect(right(core))
        core.state.apply(.windowFocused(WindowID(22)))
        #expect(right(core))
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        #expect(core.state.workspaces.lastFocused == WindowID(11))
    }

    @Test("a screen showing no window is skipped")
    func emptyScreenIsSkipped() {
        guard let core = twoScreens(emptyMain: true) else { return }
        #expect(right(core))
        // Nothing to land on there: the wrap stays on this screen.
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        #expect(core.state.workspaces.lastFocused == WindowID(11))
    }

    @Test("This screen never leaves the screen")
    func thisScreenStays() {
        guard let core = twoScreens() else { return }
        core.execute("set_focus_wrap", args: [.string("this_screen")])
        #expect(right(core))
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        #expect(core.state.workspaces.lastFocused == WindowID(11))
    }

    @Test("Off stops at the screen edge")
    func offStops() {
        guard let core = twoScreens() else { return }
        core.execute("set_focus_wrap", args: [.string("off")])
        #expect(!right(core))
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
    }

    @Test("a Scrolling row walks its whole order before it crosses")
    func scrollingWalksItsOrder() {
        guard let core = twoScreens() else { return }
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        core.state.apply(.windowFocused(WindowID(11)))
        #expect(right(core))
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        #expect(core.state.workspaces.lastFocused == WindowID(12))
        #expect(right(core))
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
    }

    @Test("a Scrolling Space is entered at its end of order")
    func scrollingLandsAtItsEnd() {
        guard let core = twoScreens() else { return }
        core.execute(
            "set_mode",
            args: [.string("2"), .string("scrolling")]
        )
        #expect(right(core))
        #expect(core.state.workspaces.lastFocused == WindowID(21))
    }

    @Test("an empty Space still crosses to the next screen")
    func emptySpaceHops() {
        guard let core = twoScreens() else { return }
        core.state.workspaces.assign(SpaceID("4"), to: left)
        core.state.workspaces.activate(SpaceID("4"))
        #expect(right(core))
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(core.state.workspaces.lastFocused == WindowID(21))
    }

    /// The #292 preflight lets that press through only where the hop
    /// lands (#2493): live, the key reaches Space 2's window; with an
    /// ignored panel latched in front, #1336's sentence answers.
    @Test("the preflight passes an empty Space's hop, not a panel's")
    func preflightPassesTheHop() {
        guard let core = twoScreens() else { return }
        core.state.workspaces.assign(SpaceID("4"), to: left)
        core.state.workspaces.activate(SpaceID("4"))
        core.frontmostPIDProvider = { 1 }
        core.ignoredPanel.active.insert(1)
        let latched = core.execute("focus", args: [.string("right")])
        #expect(latched.error?.contains("is empty") == true)
        #expect(core.state.workspaces.activeSpace == SpaceID("4"))
        core.ignoredPanel.active.remove(1)
        let hop = core.execute("focus", args: [.string("right")])
        #expect(hop.isSuccess)
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(core.state.workspaces.lastFocused == WindowID(21))
    }

    /// A Stack run on the main screen hides windows behind its edge
    /// slot (#2235): a hop entering past them lands on a shown one.
    @Test("a hop never lands on a window a run hides")
    func hopSkipsHiddenRunMembers() throws {
        guard let core = twoScreens() else { return }
        for id in UInt32(23)...26 {
            core.state.workspaces.activate(SpaceID("2"))
            core.state.apply(.windowCreated(window(id, x: 740)))
        }
        core.execute("set_mode", args: [.string("2"), .string("stack")])
        core.execute("set_min_window_size", args: [.number(300)])
        core.state.workspaces.activate(SpaceID("2"))
        core.retile(animated: false)
        let hidden = core.runHidden
        try #require(!hidden.isEmpty)
        // Back on the left screen, at its left edge: ← wraps round
        // to the main screen, entering through its right edge.
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowFocused(WindowID(11)))
        #expect(
            core.navigate([.string("left")], swapping: false).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        let landed = try #require(core.state.workspaces.lastFocused)
        #expect(!hidden.contains(landed))
    }
}
