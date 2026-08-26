import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The sibling ACTIVATION echo revert (#1049): raising an app's
/// float provokes the app into activating itself and keying its
/// MAIN window — a window the raise never stamped, so the
/// per-window z-order net missed it and the steal was honored,
/// closing a ~2 s focus loop with no user input (the Android
/// emulator's Qt window). The predicate's discriminators each
/// get an arm; the loop-terminating STAMPED re-assert gets its
/// own, because deleting it leaves every revert assertion green
/// while the loop survives one lap longer.
@Suite("Sibling activation echo (#1049)", .serialized)
@MainActor
struct SiblingActivationEchoTests {
    private let claude = WindowID(10)
    private let emulatorMain = WindowID(20)
    private let emulatorToolbar = WindowID(21)
    private let space = SpaceID(1)

    /// Two apps on one space: pid 1's window holds focus, pid 2
    /// owns a tiled main window and a floating toolbar — the
    /// emulator arrangement. The toolbar carries a fresh
    /// z-order raise stamp (the float raise just ran).
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { _, _, _ in }
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: claude,
                    pid: 1,
                    appName: "Claude"
                )
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: emulatorMain,
                    pid: 2,
                    appName: "qemu"
                )
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: emulatorToolbar,
                    pid: 2,
                    appName: "qemu"
                )
            )
        )
        core.state.windows.setFloating(emulatorToolbar, true)
        core.state.workspaces.focus(claude, in: space)
        core.eventLoop.elements[1] = [
            claude: AXUIElementCreateSystemWide()
        ]
        core.zOrderRaiseEchoes[emulatorToolbar] = Date()
        return core
    }

    @Test("A cross-app steal after a sibling raise is reverted")
    func crossAppStealIsReverted() {
        let core = makeCore()
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        core.handle(.windowFocused(emulatorMain))
        #expect(core.activeSpace?.focused == claude)
        #expect(
            lines.contains {
                $0.contains("sibling activation echo")
            }
        )
    }

    @Test("The re-assert is a STAMPED raise")
    func reassertIsAStampedRaise() {
        // The loop terminator: the revert's own raise must echo
        // as a self-echo, or its focus report reads as a
        // genuine change, re-raises the floats, and provokes
        // the very steal it just reverted — the #1049 loop with
        // one extra hop.
        let core = makeCore()
        core.handle(.windowFocused(emulatorMain))
        #expect(core.outstandingSelfRaises.contains(claude))
        #expect(core.selfRaiseStamps[claude] != nil)
    }

    @Test("An in-app focus change is honored")
    func inAppFocusChangeIsHonored() {
        // cmd-` in an app that owns a float: the float raise
        // follows every focus change, so an in-app arm would
        // eat the second press of every quick cycle. The steal
        // this branch exists for is cross-app by nature.
        // Ordering is load-bearing (guard-prover, 2026-08-27):
        // the window is created FIRST and the sibling focused
        // AFTER, so the fold reports `focusBefore` as a
        // same-pid sibling distinct from the reported window —
        // created last, the spawn grant makes focusBefore==id
        // and the predicate exits before the pid term is read.
        let core = makeCore()
        let second = WindowID(22)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: second,
                    pid: 2,
                    appName: "qemu"
                )
            )
        )
        core.state.workspaces.focus(emulatorMain, in: space)
        core.handle(.windowFocused(second))
        #expect(core.activeSpace?.focused == second)
    }

    @Test("A resize-provoked steal by a bound holder reverts")
    func resizeProvokedStealIsReverted() {
        // The second evidence arm (#1049 QA round 2): no raise
        // anywhere, but WE just set the reported window's frame
        // and it carries a learned bound — a known size-fighter
        // activating itself in answer to the resize.
        let core = makeCore()
        core.zOrderRaiseEchoes = [:]
        core.tiler.echoGraceOverride = { _ in true }
        let asked = CGSize(width: 1626, height: 1005)
        let snapped = CGSize(width: 439, height: 1005)
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(
                emulatorMain,
                size: asked
            )
            core.tiler.boundLearner.observe(
                emulatorMain,
                currentSize: snapped,
                settledRead: true
            )
        }
        core.handle(.windowFocused(emulatorMain))
        #expect(core.activeSpace?.focused == claude)
    }

    @Test("A recent set alone does not revert")
    func recentSetWithoutABoundIsHonored() {
        // The bound term keeps the resize arm off ordinary
        // windows: after any big retile many windows sit
        // inside their set grace, and a cmd-tab onto one must
        // stay honored.
        let core = makeCore()
        core.zOrderRaiseEchoes = [:]
        core.tiler.echoGraceOverride = { _ in true }
        core.handle(.windowFocused(emulatorMain))
        #expect(core.activeSpace?.focused == emulatorMain)
    }

    @Test("A bound alone does not revert")
    func boundWithoutARecentSetIsHonored() {
        // The recency term is the provocation half: a
        // size-fighter the engine has not touched lately that
        // gets a clickless focus is the user's cmd-tab.
        let core = makeCore()
        core.zOrderRaiseEchoes = [:]
        let asked = CGSize(width: 1626, height: 1005)
        let snapped = CGSize(width: 439, height: 1005)
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(
                emulatorMain,
                size: asked
            )
            core.tiler.boundLearner.observe(
                emulatorMain,
                currentSize: snapped,
                settledRead: true
            )
        }
        core.handle(.windowFocused(emulatorMain))
        #expect(core.activeSpace?.focused == emulatorMain)
    }

    @Test("A clicked window is honored")
    func clickedWindowIsHonored() {
        // Click provenance is proof no echo can forge (#687).
        let core = makeCore()
        core.lastLeftClick = (
            at: Date(),
            point: .zero,
            reached: emulatorMain
        )
        core.handle(.windowFocused(emulatorMain))
        #expect(core.activeSpace?.focused == emulatorMain)
    }

    @Test("A stale sibling stamp does not revert")
    func staleStampIsHonored() {
        // Past the echo window the raise cannot be the cause —
        // the report is the user's cmd-tab, however unprovoked
        // the app's timing looks.
        let core = makeCore()
        core.zOrderRaiseEchoes[emulatorToolbar] =
            Date().addingTimeInterval(
                -KiwiCore.zOrderRaiseEchoWindow - 1
            )
        core.handle(.windowFocused(emulatorMain))
        #expect(core.activeSpace?.focused == emulatorMain)
    }
}
