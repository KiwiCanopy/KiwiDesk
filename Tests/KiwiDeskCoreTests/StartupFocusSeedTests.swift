import Foundation
import Testing

@testable import KiwiDeskCore

/// Startup focus seeding (#442): after boot, the frontmost
/// managed window seeds focus unconditionally (OS truth), and
/// the first-member fallback fills the anchor only when nothing
/// is focused — so focused commands work before the first click
/// without ever overriding a real observed focus.
@Suite("Startup focus seed")
@MainActor
struct StartupFocusSeedTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-seed-\(UUID().uuidString)"
                )
        )
    }

    private func add(_ core: KiwiCore, _ id: UInt32) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: 100,
                    appName: "App"
                )
            )
        )
    }

    /// Forces the cold-boot focus state (#442): windows
    /// tracked, `Space.focused` nil, anchor nil. `lastFocused`
    /// still names a member, which the anchor ignores — as
    /// after a session restore whose focused window was not
    /// re-observed.
    private func wipeFocus(_ core: KiwiCore) {
        core.state.workspaces.withSpace(SpaceID(1)) {
            $0.focused = nil
        }
        #expect(core.focusedWindowID == nil)
    }

    @Test("Frontmost member seeds focus unconditionally")
    func frontmostOverridesArbitraryFocus() {
        let core = makeCore()
        add(core, 1)
        add(core, 2)
        // Discovery left focus on the last-scanned window (2),
        // but the user is looking at window 1.
        #expect(core.focusedWindowID == WindowID(2))
        core.seedStartupFocus(frontmost: WindowID(1))
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("Unresolvable frontmost never disturbs a real focus")
    func keepsExistingFocusWithoutFrontmost() {
        let core = makeCore()
        add(core, 1)
        add(core, 2)
        core.seedStartupFocus(frontmost: nil)
        #expect(core.focusedWindowID == WindowID(2))
        // A frontmost id that is not on the active space (an
        // unmanaged window resolved to a stale id) is a guess,
        // not OS truth — it must not reroute focus either.
        core.seedStartupFocus(frontmost: WindowID(99))
        #expect(core.focusedWindowID == WindowID(2))
    }

    @Test("Fallback seeds the first tiled member when nil")
    func fallbackSeedsFirstTiled() {
        let core = makeCore()
        add(core, 1)
        add(core, 2)
        wipeFocus(core)
        core.seedStartupFocus(frontmost: nil)
        #expect(core.focusedWindowID == WindowID(1))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
    }

    @Test("Fallback skips floats while a tiled member exists")
    func fallbackPrefersTiled() {
        let core = makeCore()
        add(core, 1)
        #expect(core.execute("make_floating").isSuccess)
        add(core, 2)
        wipeFocus(core)
        core.seedStartupFocus(frontmost: nil)
        #expect(core.focusedWindowID == WindowID(2))
    }

    @Test("All-floating space seeds its first window")
    func fallbackAllFloating() {
        let core = makeCore()
        add(core, 1)
        #expect(core.execute("make_floating").isSuccess)
        wipeFocus(core)
        core.seedStartupFocus(frontmost: nil)
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("Empty space stays unfocused without crashing")
    func emptySpaceNoOp() {
        let core = makeCore()
        wipeFocus(core)
        core.seedStartupFocus(frontmost: nil)
        #expect(core.focusedWindowID == nil)
    }

    @Test("A frontmost sticky traveler folds into its home slot")
    func frontmostTravelerSeedsHomeFocus() {
        let core = makeCore()
        add(core, 1)
        // Window 9: a floating global sticky homed on space 2,
        // rendered over the active space and OS-frontmost at
        // boot.
        core.state.workspaces.ensureSpace(SpaceID(2))
        var sticky = ManagedWindow(
            id: WindowID(9),
            pid: 200,
            appName: "Sticky",
            stickyScope: .global
        )
        sticky.isFloating = true
        core.state.windows.upsert(sticky)
        core.state.workspaces.add(WindowID(9), to: SpaceID(2))
        wipeFocus(core)
        core.seedStartupFocus(frontmost: WindowID(9))
        // Folded home (the membership-guarded slot), surfaced on
        // the active space through the #416 anchor.
        #expect(
            core.state.workspaces[SpaceID(2)]?.focused
                == WindowID(9)
        )
        #expect(core.focusedWindowID == WindowID(9))
    }

    @Test("Frontmost seed satisfies the #292 guard")
    func seededFocusUnblocksFocusedCommands() {
        let core = makeCore()
        add(core, 1)
        wipeFocus(core)
        // Cold state: the guard fails closed before any seed.
        core.frontmostPIDProvider = { 100 }
        #expect(!core.execute("make_floating").isSuccess)
        core.seedStartupFocus(frontmost: WindowID(1))
        // pid matches, but observation is still required — the
        // seed only fills the anchor half of the guard.
        #expect(core.focusedWindowID == WindowID(1))
    }
}
