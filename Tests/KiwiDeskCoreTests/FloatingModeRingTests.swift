import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The unfocused focus ring reaches every free float — a member
/// of a `.floating` space and a flag-floating window alike
/// (#1286, owner ruling 2026-09-13). The ring used to ask the
/// flag: a flag-float never rang unfocused while a floating-mode
/// member did, and #278 had recorded no reason for the exclusion.
/// The ring sits behind its window (#278), so an overlapped float
/// shows its ring where it peeks out and hides nothing.
///
/// Consumer-side: drives `desiredBorderSpecs` through a core, so
/// a float exclusion re-introduced on either arm reds here.
@Suite("Float focus rings (#1286)", .serialized)
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

    @Test("Floating-mode members both wear a ring")
    func floatingModeMembersRing() {
        let core = makeCore()
        seed(core, mode: .floating)
        let style = core.tiler.settings.borderStyle
        let drawn = rings(core)
        #expect(drawn[WindowID(1)] == style.focusedColor)
        #expect(drawn[WindowID(2)] == style.unfocusedColor)
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

    /// The flag arm: a flag-float on a bsp space rings unfocused
    /// too — the two arms answer alike in THIS direction.
    @Test("A flag-float on a bsp space wears the unfocused ring")
    func flagFloatRingsWhenUnfocused() {
        let core = makeCore()
        seed(core, mode: .bsp)
        core.state.setFloating(WindowID(2), true)
        let style = core.tiler.settings.borderStyle
        #expect(rings(core)[WindowID(2)] == style.unfocusedColor)
    }

    /// A tiled sticky homed elsewhere renders into the floating
    /// space as a free frame (#1217) and rings there like any
    /// other slot.
    @Test("A tiled-sticky traveler on a floating space rings")
    func travelerIntoFloatingSpaceRings() {
        let core = makeCore()
        seed(core, mode: .floating)
        core.state.workspaces.ensureSpace("2")
        core.state.windows.upsert(window(50, sticky: .global))
        core.state.workspaces.add(WindowID(50), to: "2")
        let style = core.tiler.settings.borderStyle
        #expect(rings(core)[WindowID(50)] == style.unfocusedColor)
    }

    /// Monocle stays focused-only (#278): only one window shows.
    @Test("Monocle still draws the focused ring alone")
    func monocleStaysFocusedOnly() {
        let core = makeCore()
        seed(core, mode: .monocle)
        #expect(rings(core)[WindowID(2)] == nil)
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
