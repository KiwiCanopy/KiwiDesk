import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The sticky verbs (#414): `make_sticky` / `make_unsticky` /
/// `toggle_sticky` flip the focused window's `isSticky` flag.
/// No mode argument and no tri-state — sticky has no detection
/// source, so on/off is the whole story, and the window keeps
/// its float/tiled state untouched.
@Suite("Sticky commands", .serialized)
@MainActor
struct StickyCommandTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-sticky-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(_ core: KiwiCore, _ raw: UInt32) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 1,
                    appName: "App\(raw)"
                )
            )
        )
    }

    private func isSticky(_ core: KiwiCore) -> Bool? {
        core.state.windows[WindowID(1)]?.isSticky
    }

    private func scope(_ core: KiwiCore) -> StickyScope? {
        core.state.windows[WindowID(1)]?.stickyScope
    }

    @Test("make_display_sticky sets the display scope")
    func makeDisplaySticky() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_display_sticky").isSuccess)
        #expect(scope(core) == .display)
        #expect(isSticky(core) == true)
    }

    @Test("each make_* verb overrides the other scope")
    func scopeOverride() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_sticky").isSuccess)
        #expect(scope(core) == .global)
        // make_display_sticky on a global sticky → display.
        #expect(core.execute("make_display_sticky").isSuccess)
        #expect(scope(core) == .display)
        // make_sticky on a display sticky → global.
        #expect(core.execute("make_sticky").isSuccess)
        #expect(scope(core) == .global)
        #expect(core.execute("make_unsticky").isSuccess)
        #expect(scope(core) == StickyScope.none)
    }

    @Test("toggle_display_sticky flips display against off")
    func toggleDisplay() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("toggle_display_sticky").isSuccess)
        #expect(scope(core) == .display)
        #expect(core.execute("toggle_display_sticky").isSuccess)
        #expect(scope(core) == StickyScope.none)
    }

    @Test("toggle_display_sticky on a global sticky switches scope")
    func toggleDisplayFromGlobal() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_sticky").isSuccess)
        // Toggling the OTHER scope switches, never turns off.
        #expect(core.execute("toggle_display_sticky").isSuccess)
        #expect(scope(core) == .display)
        // And toggle_sticky on a display sticky switches to global.
        #expect(core.execute("toggle_sticky").isSuccess)
        #expect(scope(core) == .global)
    }

    @Test("make_sticky marks the focused window")
    func makeSticky() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(isSticky(core) == false)
        #expect(core.execute("make_sticky").isSuccess)
        #expect(isSticky(core) == true)
    }

    @Test("make_unsticky clears the flag")
    func makeUnsticky() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_sticky").isSuccess)
        #expect(core.execute("make_unsticky").isSuccess)
        #expect(isSticky(core) == false)
    }

    @Test("two toggles return to the original state")
    func toggleRoundTrip() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("toggle_sticky").isSuccess)
        #expect(isSticky(core) == true)
        #expect(core.execute("toggle_sticky").isSuccess)
        #expect(isSticky(core) == false)
    }

    @Test("sticky leaves the float state untouched")
    func orthogonalToFloat() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.execute("make_sticky").isSuccess)
        let window = core.state.windows[WindowID(1)]
        #expect(window?.isFloating == true)
        #expect(window?.isSticky == true)
        #expect(core.execute("make_tiled").isSuccess)
        #expect(
            core.state.windows[WindowID(1)]?.isSticky == true
        )
    }

    @Test("sticky verbs without a focused window fail")
    func failsWithoutFocus() {
        let core = makeCore()
        #expect(!core.execute("make_sticky").isSuccess)
        #expect(!core.execute("make_unsticky").isSuccess)
        #expect(!core.execute("toggle_sticky").isSuccess)
    }

    @Test("sticky.set_mark writes the style, unclamped")
    func setMark() {
        let core = makeCore()
        #expect(core.tiler.settings.stickyStyle.mark)
        #expect(
            core.execute(
                "sticky.set_mark",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.stickyStyle.mark)
        // No coverage-guard clamp here: off stays off even
        // with the Space Bar also off (Lua is open, #414).
        #expect(
            core.execute(
                "space_bar.set_enabled",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.stickyStyle.mark)
    }

    @Test("sticky.set_mark rejects non-boolean input")
    func setMarkRejects() {
        let core = makeCore()
        #expect(
            !core.execute(
                "sticky.set_mark",
                args: [.string("yes")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "sticky.set_unknown",
                args: [.bool(true)]
            ).isSuccess
        )
    }

    @Test("space_bar.set_sticky_badge writes the style")
    func setStickyBadge() {
        let core = makeCore()
        #expect(core.tiler.settings.spaceBarStyle.stickyBadge)
        #expect(
            core.execute(
                "space_bar.set_sticky_badge",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(
            !core.tiler.settings.spaceBarStyle.stickyBadge
        )
    }

    @Test("sticky verbs are listed in the API reference")
    func listedInReference() {
        for verb in [
            "make_sticky", "make_display_sticky", "make_unsticky",
            "toggle_sticky", "toggle_display_sticky",
        ] {
            #expect(
                APIReference.commands.contains {
                    $0.command == verb
                }
            )
        }
    }
}

/// Sticky windows are focusable from every space (#414): a
/// focus landing on one whose HOME space is inactive must NOT
/// pull that space forward — following it yanked the user back
/// to the origin space on every interaction (the QA fly-back).
@Suite("Sticky focus follow", .serialized)
@MainActor
struct StickyFocusFollowTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-follow-\(UUID().uuidString)"
                )
        )
    }

    private func seed(_ core: KiwiCore) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "App"
                )
            )
        )
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.activate(SpaceID(2))
    }

    @Test("A foreign sticky focus schedules no follow")
    func stickyExempt() {
        let core = makeCore()
        seed(core)
        core.state.setSticky(WindowID(1), .global)
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.deferred.task(for: .focusFollow) == nil)
        #expect(
            core.state.workspaces.activeSpace == SpaceID(2)
        )
    }

    @Test("A foreign non-sticky focus still follows")
    func nonStickyFollows() {
        let core = makeCore()
        seed(core)
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }
}

/// Close/reopen persistence of the sticky intent (#414),
/// mirroring the float persistence (#160): identity is app +
/// title, an empty title carries no identity, and the last
/// close wins for a shared identity.
@Suite("Sticky persistence")
struct StickyPersistenceTests {
    private func makeWindow(
        _ id: UInt32,
        pid: pid_t = 100,
        title: String = "Doc"
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "TestApp",
            title: title
        )
    }

    @Test("make_sticky survives close and reopen")
    func stickySurvivesReopen() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isSticky == true)
    }

    @Test("an unsticky close clears a stale remembered intent")
    func unstickyCloseClears() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        // Reopen restores sticky; the user then turns it off.
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isSticky == true)
        state.setSticky(WindowID(2), .none)
        state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(3)))
        #expect(state.windows[WindowID(3)]?.isSticky == false)
    }

    @Test("app termination remembers sticky for relaunch")
    func appTerminationRemembers() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(.appTerminated(pid: 100))
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isSticky == true)
    }

    @Test("a late-loading title still restores the intent")
    func lazyTitleRestores() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2, title: "")))
        #expect(state.windows[WindowID(2)]?.isSticky == false)
        state.apply(.windowTitleChanged(WindowID(2), "Doc"))
        #expect(state.windows[WindowID(2)]?.isSticky == true)
    }

    @Test("empty titles carry no identity to remember")
    func emptyTitleNeverRemembered() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1, title: "")))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2, title: "")))
        #expect(state.windows[WindowID(2)]?.isSticky == false)
    }

    @Test("the restored intent re-arms for the next cycle")
    func restoredIntentRearms() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(3)))
        #expect(state.windows[WindowID(3)]?.isSticky == true)
    }

    @Test("untracked ids never record an intent")
    func untrackedIdIgnored() {
        var state = StateCoordinator()
        state.setSticky(WindowID(9), .global)
        state.apply(.windowCreated(makeWindow(9)))
        #expect(state.windows[WindowID(9)]?.isSticky == false)
    }

    @Test("a rekey carries the sticky flag to the new id")
    func rekeyCarriesFlag() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setSticky(WindowID(1), .global)
        state.apply(
            .windowRekeyed(WindowID(1), WindowID(2))
        )
        #expect(state.windows[WindowID(2)]?.isSticky == true)
    }
}
