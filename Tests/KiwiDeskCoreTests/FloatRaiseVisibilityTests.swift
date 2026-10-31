import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The float-tier raise leaves out a float the WindowServer draws
/// at no visible size (#2840): BetterDisplay's 1×1 helper was the
/// one target of every focus step's raise in a BSP Space, three
/// whole-list reads each. `floatLayerTargets` keeps it — the
/// filter is the raise's alone (`drawnFloatTargets`). Bounds come
/// through the watch's `readWindowBounds` seam, so the real
/// verdict runs through the real consumer.
@Suite("Float raise skips undrawn floats (#2840)", .serialized)
@MainActor
struct FloatRaiseVisibilityTests {
    private func window(
        _ id: UInt32,
        isFloating: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            title: "Title",
            frame: CGRect(x: 100, y: 100, width: 400, height: 300),
            isFloating: isFloating
        )
    }

    /// Space "1" (bsp, active) holds tiles 1 and 2 and floats 50
    /// and 60; `undrawn` names the floats the WindowServer reads
    /// at BetterDisplay's 1×1, every other id at a window's size.
    private func makeCore(undrawn: Set<UInt32>) -> KiwiCore {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.setMode("1", .bsp)
        core.state.workspaces.activate("1")
        for id: UInt32 in [1, 2] {
            core.state.windows.upsert(window(id))
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        for id: UInt32 in [50, 60] {
            core.state.windows.upsert(window(id, isFloating: true))
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.windowServer.readWindowBounds = { id in
            undrawn.contains(id.raw)
                ? CGRect(x: 9, y: 41, width: 1, height: 1)
                : CGRect(x: 100, y: 100, width: 400, height: 300)
        }
        return core
    }

    @Test("A focus beside only undrawn floats schedules no raise")
    func undrawnFloatsRaiseNothing() {
        let core = makeCore(undrawn: [50, 60])
        core.raiseFloatsAbove(afterFocusing: WindowID(1))
        #expect(!core.deferred.isScheduled(.floatRaise))
        #expect(core.drawnFloatTargets().isEmpty)
    }

    @Test("A drawn float still schedules the raise")
    func drawnFloatRaises() {
        let core = makeCore(undrawn: [])
        core.raiseFloatsAbove(afterFocusing: WindowID(1))
        #expect(core.deferred.isScheduled(.floatRaise))
        core.deferred.cancel(.floatRaise)
    }

    @Test("Only the undrawn float leaves the raise's targets")
    func filterIsPerWindow() {
        let core = makeCore(undrawn: [50])
        #expect(core.drawnFloatTargets() == [WindowID(60)])
        #expect(
            core.floatLayerTargets() == [WindowID(50), WindowID(60)]
        )
    }

    @Test(
        "A side of 1 pt or less is no visible size; no answer keeps",
        arguments: [
            (CGRect(x: 9, y: 41, width: 1, height: 1), false),
            (CGRect(x: 0, y: 0, width: 1, height: 300), false),
            (CGRect(x: 0, y: 0, width: 300, height: 0), false),
            (CGRect(x: 0, y: 0, width: 2, height: 2), true),
            (CGRect(x: 0, y: 0, width: 400, height: 300), true),
        ]
    )
    func verdict(bounds: CGRect, drawn: Bool) {
        #expect(FloatDetection.drawsVisibly(bounds: bounds) == drawn)
    }

    @Test("A read with no answer keeps the window")
    func nilKeeps() {
        #expect(FloatDetection.drawsVisibly(bounds: nil))
        let core = makeCore(undrawn: [])
        core.windowServer.readWindowBounds = { _ in nil }
        #expect(
            core.drawnFloatTargets() == [WindowID(50), WindowID(60)]
        )
    }
}
