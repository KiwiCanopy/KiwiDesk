import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #2985: focusing a float schedules no raise, since it needs none
/// for itself, so a raise owed to the tile focused just before was all
/// that would lift the other floats back over the tiles. Observed
/// through the debt: the AX drain is not reachable here, so the raise
/// itself is `ZOrderScrollingRestoreWiringTests`'s.
@Suite("A focused float still gets the layer raised (#2985)", .serialized)
@MainActor
struct FocusedFloatRaiseTests {
    private let tile = WindowID(1)
    private let float = WindowID(7)

    /// Space "1" holds tile 1 and float 7, with the float focused and
    /// the plane moving, unless a test says otherwise.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-focused-float-\(UUID().uuidString)"
                )
        )
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.setMode("1", .bsp)
        core.state.workspaces.activate("1")
        for (id, floats) in [(tile, false), (float, true)] {
            core.state.windows.upsert(
                ManagedWindow(
                    id: id,
                    pid: pid_t(900_000 + Int(id.raw)),
                    appName: "App",
                    title: "Title",
                    frame: CGRect(x: 100, y: 100, width: 400, height: 300),
                    isFloating: floats
                )
            )
            core.state.workspaces.add(id, to: "1")
        }
        core.state.workspaces.focus(float, in: "1")
        core.floatRaiseDebt.restoresInFlight = 1
        #expect(core.focusedWindowID == float)
        return core
    }

    @Test("A debt to the tile left behind passes to the float")
    func debtPassesToTheFloat() {
        let core = makeCore()
        core.floatRaiseDebt.owed = tile
        core.runPendingFloatRaise()
        #expect(core.floatRaiseDebt.owed == float)
    }

    /// The timer's arm: the float's focus lands inside the tile's
    /// 50 ms coalescing.
    @Test("A scheduled raise for the tile pays for the float")
    func scheduledRaisePays() async throws {
        let core = makeCore()
        core.state.workspaces.focus(tile, in: "1")
        core.raiseFloatsAbove(afterFocusing: tile)
        let task = try #require(core.deferred.task(for: .floatRaise))
        core.state.workspaces.focus(float, in: "1")
        await task.value
        #expect(core.floatRaiseDebt.owed == float)
    }

    /// The control: a tile's focus takes the path it always took.
    @Test("A focused tile is not the float's case")
    func tileStandsAside() {
        let core = makeCore()
        core.state.workspaces.focus(tile, in: "1")
        #expect(!core.raiseFloatsForFocusedFloat())
        #expect(core.floatRaiseDebt.owed == nil)
    }
}
