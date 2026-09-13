import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The float-tier raise stands down after a focus that lands on
/// an EFFECTIVE float (#1286): a member of a `.floating` space,
/// exactly as a flag-floating window. `raiseFloatsAbove` asked
/// the flag alone, so a floating-mode member counted as the tiled
/// PLANE, and every member focus pulled a flagged or sticky float
/// back over its siblings — an order the user could never keep.
///
/// The targets (`floatLayerTargets`) stay the flag's by ruling:
/// the tier lifts floats over a tiled plane, and a floating-mode
/// space has none. Observed through the `.floatRaise` deferred
/// slot rather than the AX drain, which is not reachable here.
///
/// `EffectiveFloatTests` holds the predicate's own algebra; this
/// suite is the consumer, which that one structurally cannot see.
@Suite("Floating-mode float-tier raise (#1286)", .serialized)
@MainActor
struct FloatingModeRaiseTests {
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
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

    /// Space "1" (active, in `mode`) holds windows 1 and 2; a
    /// floating global sticky (50) homes on space "2", so the
    /// float layer is never empty and only the focus class decides.
    private func seed(_ core: KiwiCore, mode: LayoutMode) {
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.setMode("1", mode)
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

    @Test("A floating-mode member's focus schedules no raise")
    func floatingModeFocusStandsDown() {
        let core = makeCore()
        seed(core, mode: .floating)
        core.raiseFloatsAbove(afterFocusing: WindowID(1))
        #expect(!core.deferred.isScheduled(.floatRaise))
    }

    @Test("The same focus under bsp schedules the raise")
    func tiledFocusRaises() {
        let core = makeCore()
        seed(core, mode: .bsp)
        core.raiseFloatsAbove(afterFocusing: WindowID(1))
        #expect(core.deferred.isScheduled(.floatRaise))
        core.deferred.cancel(.floatRaise)
    }

    /// The flag arm, unchanged: a flag-float's focus on a bsp
    /// space is the case the mode arm is being held equal to.
    @Test("A flag-float's focus on a bsp space schedules no raise")
    func flagFloatFocusStandsDown() {
        let core = makeCore()
        seed(core, mode: .bsp)
        core.state.setFloating(WindowID(1), true)
        core.raiseFloatsAbove(afterFocusing: WindowID(1))
        #expect(!core.deferred.isScheduled(.floatRaise))
    }

    /// The targets are the flag's on every mode: a floating-mode
    /// member is not lifted, only the flagged and the sticky
    /// floats are — there is no plane in that space to lift over.
    @Test("Floating-mode members never join the float layer")
    func targetsStayTheFlags() {
        let core = makeCore()
        seed(core, mode: .floating)
        #expect(core.floatLayerTargets() == [WindowID(50)])
        core.state.setFloating(WindowID(2), true)
        #expect(
            core.floatLayerTargets() == [WindowID(2), WindowID(50)]
        )
    }
}
