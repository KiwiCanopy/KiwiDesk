import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #463: focusing a space moved the focus ring but no
/// window actually received keyboard focus. The switch must
/// always resolve a real handoff target (falling back to the
/// space's first member), yield to the desktop when the target
/// space has nothing to focus (else the previous space's
/// stashed window keeps swallowing keystrokes), and the settle
/// re-asserts the raise when the OS provably dropped the
/// cooperative activate.
@Suite("Space-switch focus handoff (#463)", .serialized)
@MainActor
struct SpaceSwitchFocusHandoffTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-handoff-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        pid: pid_t = 1
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: pid,
                    appName: "App\(pid)"
                )
            )
        )
    }

    /// One shared generous hang-guard (#344): the poll below
    /// exits the moment its condition holds, so a passing run
    /// never waits this out — it only bounds a genuine hang.
    private let handoffHangGuardMS = 30_000

    private func pollUntil(
        _ condition: () -> Bool
    ) async {
        var waited = 0
        while !condition(), waited < handoffHangGuardMS {
            try? await Task.sleep(for: .milliseconds(20))
            waited += 20
        }
    }

    private func makeStickyFloat(
        _ raw: UInt32,
        pid: pid_t
    ) -> ManagedWindow {
        var window = ManagedWindow(
            id: WindowID(raw),
            pid: pid,
            appName: "Sticky\(pid)",
            stickyScope: .global
        )
        window.isFloating = true
        return window
    }

    @Test("Switching to an empty space yields to the desktop")
    func emptySwitchYieldsDesktopFocus() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        addWindow(core, 1)
        #expect(core.activeSpace?.focused == WindowID(1))
        core.execute("focus_space", args: [.string("2")])
        // Window 1 is stashed offscreen yet still key — the
        // desktop must take over instead (#463).
        #expect(yields == 1)
    }

    @Test("Switching to a space with a focus does not yield")
    func populatedSwitchSkipsYield() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        addWindow(core, 1)
        addWindow(core, 2)
        core.moveWindow(
            WindowID(2),
            to: SpaceID(2),
            follow: false
        )
        yields = 0
        core.execute("focus_space", args: [.string("2")])
        #expect(yields == 0)
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    /// The yield keys on the stashed window's app still being
    /// frontmost: when the user's real focus is an UNMANAGED
    /// app (no managed window echoes moved `lastFocused`),
    /// activating Finder would steal from it — worse than the
    /// swallowed keys.
    @Test("No yield when an unmanaged app is frontmost")
    func unmanagedFrontmostSkipsYield() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        core.frontmostPIDProvider = { 42 }
        addWindow(core, 1, pid: 7)
        core.execute("focus_space", args: [.string("2")])
        #expect(yields == 0)
    }

    /// A space holding members but no stamped focus (#463's
    /// "fallback that was never raised"): the switch stamps the
    /// first member as focus so the ring and the raise cannot
    /// disagree.
    @Test("A member space without a focus stamps its first")
    func fallbackStampsFirstMember() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        addWindow(core, 1)
        // Bare membership move: unlike `move_to_space`, this
        // stamps no focus on space 2 — the defensive gap the
        // fallback closes.
        core.state.workspaces.add(WindowID(1), to: SpaceID(2))
        #expect(
            core.state.workspaces[SpaceID(2)]?.focused == nil
        )
        core.execute("focus_space", args: [.string("2")])
        #expect(
            core.state.workspaces[SpaceID(2)]?.focused
                == WindowID(1)
        )
        #expect(yields == 0)
    }

    /// The yield leg with the seam wired AND agreeing: the
    /// stashed window's app is still frontmost — fire.
    @Test("Yield fires when the stashed app is still frontmost")
    func wiredMatchingFrontmostYields() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        core.frontmostPIDProvider = { 7 }
        addWindow(core, 1, pid: 7)
        core.execute("focus_space", args: [.string("2")])
        #expect(yields == 1)
    }

    /// A floating sticky (visible on every space) is a
    /// legitimate focus recipient whose in-flight raise would
    /// race a Finder activate — the empty-switch yield skips
    /// while the float layer is populated (review).
    @Test("A visible floating sticky suppresses the yield")
    func visibleStickySkipsYield() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        core.state.apply(
            .windowCreated(makeStickyFloat(50, pid: 6))
        )
        addWindow(core, 1, pid: 5)
        // Window 1 is the focus; space 2 is empty of members,
        // but the sticky travels there — no desktop yield.
        core.state.apply(.windowFocused(WindowID(1)))
        core.execute("focus_space", args: [.string("2")])
        #expect(yields == 0)
    }

    /// The #431 hazard, pinned: a floating-sticky traveler that
    /// holds the real focus IS the switch's anchor — the
    /// fallback must not stamp the empty space's focus, and the
    /// settle must not "correct" the traveler back (its own app
    /// frontmost means agreement).
    @Test("A sticky traveler anchor is neither stamped nor fought")
    func stickyTravelerAnchorUntouched() {
        let core = makeCore()
        var yields = 0
        var logs: [String] = []
        core.desktopFocusYield = { yields += 1 }
        core.onLog = { logs.append($0) }
        addWindow(core, 1, pid: 5)
        core.state.apply(
            .windowCreated(makeStickyFloat(50, pid: 6))
        )
        // The sticky is `lastFocused` (created last) and renders
        // on the active space wherever the user goes.
        #expect(
            core.state.workspaces.lastFocused == WindowID(50)
        )
        core.execute("focus_space", args: [.string("2")])
        // Anchor resolved to the traveler: no stamp, no yield.
        #expect(
            core.state.workspaces[SpaceID(2)]?.focused == nil
        )
        #expect(yields == 0)
        // Settle-side: the traveler's app frontmost = agreement.
        logs = []
        core.frontmostPIDProvider = { 6 }
        core.reassertSwitchFocus(
            priorFrontmost: 6,
            context: "space settle"
        )
        #expect(logs.isEmpty)
    }

    /// The settle's dropped-activate detection: the app that
    /// was frontmost BEFORE the switch still is at settle time,
    /// and it is not the focused window's app — the cooperative
    /// activate provably never landed, so the settle re-raises
    /// once (and says so).
    @Test("Settle re-raises when the OS dropped the activate")
    func settleReassertsDroppedActivate() async {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        // The previous app (pid 5) never loses frontmost.
        core.frontmostPIDProvider = { 5 }
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        core.moveWindow(
            WindowID(20),
            to: SpaceID(2),
            follow: false
        )
        core.execute("focus_space", args: [.string("2")])
        await pollUntil {
            logs.contains { $0.contains("re-raising") }
        }
        #expect(
            logs.contains {
                $0.contains("space settle")
                    && $0.contains("re-raising window 20")
            }
        )
    }

    /// Guard unit-coverage for the re-assert, decision by
    /// decision — synchronous, no timers.
    @Test("Re-assert guards: moved-on and same-app hands off")
    func reassertGuardsHandOff() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        core.moveWindow(
            WindowID(20),
            to: SpaceID(2),
            follow: false
        )
        core.execute("focus_space", args: [.string("2")])
        logs = []
        // Frontmost changed since the switch: user moved on.
        core.frontmostPIDProvider = { 7 }
        core.reassertSwitchFocus(
            priorFrontmost: 5,
            context: "space settle"
        )
        #expect(logs.isEmpty)
        // Frontmost unchanged but IS the focused window's app:
        // the handoff landed (same-app switch) — nothing to do.
        core.frontmostPIDProvider = { 6 }
        core.reassertSwitchFocus(
            priorFrontmost: 6,
            context: "space settle"
        )
        #expect(logs.isEmpty)
        // No capture (seam unwired at switch time): inert.
        core.reassertSwitchFocus(
            priorFrontmost: nil,
            context: "space settle"
        )
        #expect(logs.isEmpty)
        // The genuine drop still fires.
        core.frontmostPIDProvider = { 5 }
        core.reassertSwitchFocus(
            priorFrontmost: 5,
            context: "space settle"
        )
        #expect(logs.count == 1)
    }
}
