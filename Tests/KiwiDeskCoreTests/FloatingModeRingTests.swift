import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The unfocused focus ring stands down for an EFFECTIVE float
/// (#1286): a member of a `.floating` space, exactly as a
/// flag-floating window. The ring asked the flag alone, so every
/// member of a floating-mode space kept an unfocused ring — drawn
/// across whichever window sat in front of it.
///
/// `EffectiveFloatTests` holds the predicate's own algebra; this
/// suite is the consumer, which that one structurally cannot see.
@Suite("Floating-mode focus ring (#1286)", .serialized)
@MainActor
struct FloatingModeRingTests {
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        // Pin the display (#531): the ring reads each window's
        // real frame, and the slots fall back to it.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.tiler.settings.borderStyle.enabled = true
        core.tiler.settings.borderStyle.unfocusedEnabled = true
        return core
    }

    private func window(
        _ id: UInt32,
        isFloating: Bool = false,
        isFullscreen: Bool = false,
        sticky: StickyScope = .none
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            title: "Title",
            frame: CGRect(
                x: 100 * Double(id),
                y: 100,
                width: 400,
                height: 300
            ),
            isFloating: isFloating,
            stickyScope: sticky,
            isFullscreen: isFullscreen
        )
    }

    /// Space "1" (active, in `mode`) holds windows 1 and 2, window
    /// 1 focused.
    private func seed(_ core: KiwiCore, mode: LayoutMode) {
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.setMode("1", mode)
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...2 {
            core.state.windows.upsert(window(id))
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.workspaces.focus(WindowID(1), in: "1")
    }

    private func rings(_ core: KiwiCore) -> [WindowID: String] {
        Dictionary(
            core.desiredBorderSpecs().map { ($0.window, $0.colorHex) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    @Test("A floating-mode member keeps the focused ring only")
    func floatingModeMemberHasNoUnfocusedRing() {
        let core = makeCore()
        seed(core, mode: .floating)
        let style = core.tiler.settings.borderStyle
        let drawn = rings(core)
        #expect(drawn[WindowID(1)] == style.focusedColor)
        #expect(drawn[WindowID(2)] == nil)
    }

    @Test("The same two windows under bsp both wear a ring")
    func tiledMembersKeepBothRings() {
        let core = makeCore()
        seed(core, mode: .bsp)
        let style = core.tiler.settings.borderStyle
        let drawn = rings(core)
        #expect(drawn[WindowID(1)] == style.focusedColor)
        #expect(drawn[WindowID(2)] == style.unfocusedColor)
    }

    /// The flag arm, unchanged: a flag-float on a bsp space is the
    /// case the mode arm is being held equal to.
    @Test("A flag-float on a bsp space has no unfocused ring")
    func flagFloatHasNoUnfocusedRing() {
        let core = makeCore()
        seed(core, mode: .bsp)
        core.state.setFloating(WindowID(2), true)
        #expect(rings(core)[WindowID(2)] == nil)
    }

    /// A tiled sticky homed elsewhere renders into the floating
    /// space as a free frame (#1217), so it is judged on the space
    /// it renders on — the traveler union, not `space.windows`.
    @Test("A tiled-sticky traveler on a floating space has no ring")
    func travelerIntoFloatingSpaceHasNoUnfocusedRing() {
        let core = makeCore()
        seed(core, mode: .floating)
        core.state.workspaces.ensureSpace("2")
        core.state.windows.upsert(window(50, sticky: .global))
        core.state.workspaces.add(WindowID(50), to: "2")
        #expect(
            core.state.effectiveTiledMembers(
                of: core.state.workspaces["1"]!
            ).contains(WindowID(50))
        )
        #expect(rings(core)[WindowID(50)] == nil)
    }

    /// A native-fullscreen window stands down on BOTH arms, as a
    /// whole-predicate clause (#670, the #1184 lesson): no ring
    /// whether the float is the flag's or the mode's.
    @Test("A fullscreen window has no ring on either arm")
    func fullscreenStandsDownOnBothArms() {
        for mode in [LayoutMode.floating, .bsp] {
            let core = makeCore()
            seed(core, mode: mode)
            core.state.windows.upsert(
                window(2, isFloating: mode == .bsp, isFullscreen: true)
            )
            core.state.workspaces.focus(WindowID(2), in: "1")
            #expect(rings(core)[WindowID(2)] == nil, "\(mode)")
        }
    }
}
