import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #2284: a commanded focus — a Space Bar click, a keyboard focus
/// move — raises its window itself, so the window's focus report
/// comes back as our own echo, which the focus handler skips. The
/// float layer was then never lifted back over the tile. The
/// command now schedules the raise itself; a re-assert of the
/// focused window — the raise's own hand-back — owes none.
/// Observed through the `.floatRaise` deferred slot; the AX drain
/// is not reachable here.
@Suite("Commanded focus raises the float layer (#2284)", .serialized)
@MainActor
struct CommandedFocusFloatRaiseTests {
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
        return makeTestCore(configDirectory: directory)
    }

    private func window(
        _ id: UInt32,
        isFloating: Bool = false,
        sticky: StickyScope = .none
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            title: "Title",
            frame: CGRect(x: 100, y: 100, width: 400, height: 300),
            isFloating: isFloating,
            stickyScope: sticky
        )
    }

    /// Space "1" (bsp, active) holds tiles 1 and 2, 1 focused; a
    /// floating global sticky (50) homes on "2", so the float
    /// layer is never empty.
    private func seed(_ core: KiwiCore) {
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.setMode("1", .bsp)
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...2 {
            core.state.windows.upsert(window(id))
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.windows.upsert(
            window(50, isFloating: true, sticky: .global)
        )
        core.state.workspaces.add(WindowID(50), to: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
        #expect(!core.floatLayerTargets().isEmpty)
    }

    @Test("A commanded focus onto another tile schedules the raise")
    func commandedFocusRaises() {
        let core = makeCore()
        seed(core)
        core.focusWindow(WindowID(2), warp: false)
        #expect(core.deferred.isScheduled(.floatRaise))
        core.deferred.cancel(.floatRaise)
    }

    /// A focus a door hands to ANOTHER window without retiling —
    /// a return payment, the window switcher's arrival — is a
    /// commanded focus like any other.
    @Test("A handed focus onto another tile schedules the raise")
    func handedFocusRaises() {
        let core = makeCore()
        seed(core)
        core.focusWindow(WindowID(2), refocusRetile: false, warp: false)
        #expect(core.deferred.isScheduled(.floatRaise))
        core.deferred.cancel(.floatRaise)
    }

    /// The raise's own hand-back re-asserts the window already
    /// focused; a raise there would loop.
    @Test("A re-assert of the focused tile schedules no raise")
    func sameWindowStandsDown() {
        let core = makeCore()
        seed(core)
        core.focusWindow(WindowID(1), refocusRetile: false, warp: false)
        core.focusWindow(WindowID(1), warp: false)
        #expect(!core.deferred.isScheduled(.floatRaise))
    }

    /// A door that raises the layer itself — a Space switch, a
    /// landing — supersedes a raise its own focus scheduled.
    @Test("A direct raise supersedes a scheduled or owed one")
    func directRaiseSupersedes() {
        let core = makeCore()
        seed(core)
        core.focusWindow(WindowID(2), warp: false)
        core.floatRaiseDebt.owed = WindowID(2)
        core.raiseFloatsAndSticky(thenFocus: WindowID(2))
        #expect(!core.deferred.isScheduled(.floatRaise))
        #expect(core.floatRaiseDebt.owed == nil)
    }

    /// Each arm of the wait, alone: the plane is still moving
    /// while a restore is armed or a tiled one drains.
    @Test("The wait reads an armed and a draining restore")
    func waitReadsRestores() {
        let core = makeCore()
        seed(core)
        #expect(!core.tiledPlaneMoving)
        core.pendingZOrderRestore = true
        #expect(core.tiledPlaneMoving)
        core.pendingZOrderRestore = false
        core.floatRaiseDebt.restoresInFlight = 1
        #expect(core.tiledPlaneMoving)
        core.floatRaiseDebt.restoresInFlight = 0
        // The float raise's own drain is no tiled restore: a newer
        // focus supersedes it at once.
        core.zOrderRestoresInFlight = 1
        #expect(!core.tiledPlaneMoving)
        core.zOrderRestoresInFlight = 0
    }

    /// The pan arm, which a keyboard step in scrolling meets.
    @Test(
        "The wait reads a running pan",
        .enabled(if: NSScreen.main != nil)
    )
    func waitReadsAPan() throws {
        let core = makeCore()
        seed(core)
        let screen = try #require(NSScreen.main)
        core.tiler.animation.animate(
            window: WindowID(999),
            on: screen,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 800, y: 0, width: 100, height: 100)
        )
        #expect(core.tiler.animation.activeCount > 0)
        #expect(core.tiledPlaneMoving)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// While the plane moves the scheduled raise is OWED rather
    /// than issued, and paying the debt schedules it again.
    @Test("A raise behind a restore is owed, then paid")
    func raiseIsOwedThenPaid() async throws {
        let core = makeCore()
        seed(core)
        core.floatRaiseDebt.restoresInFlight = 1
        core.raiseFloatsAbove(afterFocusing: WindowID(1))
        let first = try #require(core.deferred.task(for: .floatRaise))
        await first.value
        #expect(core.floatRaiseDebt.owed == WindowID(1))
        core.floatRaiseDebt.restoresInFlight = 0
        core.runPendingFloatRaise()
        #expect(core.floatRaiseDebt.owed == nil)
        let second = try #require(core.deferred.task(for: .floatRaise))
        #expect(second != first)
        core.deferred.cancel(.floatRaise)
    }

    /// A newer focus supersedes a raise owed to an earlier one, and
    /// a debt for a focus that moved on is dropped at payment —
    /// paying it would replace the newer focus's scheduled raise.
    @Test("A stale owed raise never replaces a newer one")
    func staleDebtIsDropped() throws {
        let core = makeCore()
        seed(core)
        core.floatRaiseDebt.owed = WindowID(1)
        core.focusWindow(WindowID(2), warp: false)
        #expect(core.floatRaiseDebt.owed == nil)
        let fresh = try #require(core.deferred.task(for: .floatRaise))
        core.floatRaiseDebt.owed = WindowID(1)
        core.runPendingFloatRaise()
        #expect(core.floatRaiseDebt.owed == nil)
        #expect(core.deferred.task(for: .floatRaise) == fresh)
        core.deferred.cancel(.floatRaise)
    }

    /// The owed-pass arm: a layout pass the hand has not let draw.
    @Test("The wait reads an owed pass")
    func waitReadsAnOwedPass() {
        let core = makeCore()
        seed(core)
        let gate = core.tiler.motionGate
        gate.schedule = { _, _ in }
        gate.onLog = { _ in }
        gate.quiescence.sinceMouseMoved = { 0 }
        #expect(!core.tiledPlaneMoving)
        let held = gate.admit(
            MotionGate.Owed(
                animated: nil,
                pass: .event,
                newlyCreatedWindow: nil,
                sizing: .mayInstantSize
            )
        )
        #expect(held == nil)
        #expect(core.tiledPlaneMoving)
        gate.dropAll()
    }
}
