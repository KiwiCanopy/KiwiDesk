import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's edges (#2446): who may file or focus the pocketed
/// window, what ends the slot, and the #292 preflight.
@Suite("Pocket edges", .serialized)
@MainActor
struct PocketEdgeTests {
    private let one = WindowID(1)
    private let two = WindowID(2)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-pocket-edge-\(UUID().uuidString)"
                )
        )
        for raw: UInt32 in [2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)"
                    )
                )
            )
        }
        core.state.apply(.windowFocused(one))
        return core
    }

    @Test("a minimize empties the pocket")
    func minimizeEmpties() {
        let core = makeCore()
        core.execute("pocket")
        core.execute("pocket")
        core.state.apply(.windowDestroyed(one, wasMinimized: true))
        #expect(core.state.pocket.isEmpty)
    }

    @Test("out, with its app hidden, the key refuses and keeps it")
    func hiddenOutRefuses() {
        let core = makeCore()
        core.execute("pocket")
        core.execute("pocket")
        core.state.apply(.windowHidden(one))
        #expect(!core.execute("pocket").isSuccess)
        #expect(core.state.pocket.first?.window == one)
    }

    @Test("an exited app's slot empties, and that press ends there")
    func exitedAppEmpties() {
        let core = makeCore()
        core.execute("pocket")
        core.state.apply(.windowHidden(one))
        core.eventLoop.processIdentity.runs = { _ in false }
        core.state.apply(.windowFocused(two))
        // A stale anchor: the filled slot passes the preflight, so
        // the purge must not go on to pocket the focus.
        core.frontmostPIDProvider = { 1 }
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocket.isEmpty)
        #expect(!core.execute("pocket").isSuccess)
        #expect(core.state.pocket.isEmpty)
    }

    @Test("the in-place slot's stored keys are pinned")
    func storedKeysArePinned() throws {
        let slot = PocketSlot(
            window: one,
            pid: 7,
            phase: .out,
            frames: ["A": .zero],
            cameFrom: two,
            owner: "app.test"
        )
        let object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(slot)
            ) as? [String: Any]
        )
        #expect(
            Set(object.keys)
                == [
                    "window", "pid", "phase", "frames", "came_from",
                    "owner",
                ]
        )
        #expect(object["phase"] as? String == "out")
    }

    @Test("focus_window on the pocketed window takes it out")
    func focusWindowTakesOut() {
        let core = makeCore()
        core.execute("pocket")
        let response = core.execute(
            "focus_window",
            args: [.number(Double(one.raw))]
        )
        #expect(response.isSuccess)
        #expect(core.state.pocketPhase(of: one) == .out)
    }

    @Test("an explicit move never files the pocketed window")
    func explicitMoveRefused() {
        let core = makeCore()
        core.execute("pocket")
        let response = core.execute(
            "move_to_space",
            args: [.string("2"), .number(Double(one.raw))]
        )
        #expect(!response.isSuccess)
        #expect(core.state.workspaces.space(of: one) == nil)
    }

    @Test("a filled pocket passes the #292 preflight; pocketing does not")
    func preflight() {
        let core = makeCore()
        core.frontmostPIDProvider = { 1 }
        #expect(!core.execute("pocket").isSuccess)
        #expect(core.state.pocket.isEmpty)
        core.frontmostPIDProvider = nil
        core.execute("pocket")
        core.frontmostPIDProvider = { 1 }
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .out)
    }

    @Test("an in-place slot waits for a window not yet tracked")
    func adoptWaitsForSlowWindow() {
        let core = makeCore()
        let late = WindowID(7)
        var snapshot = core.state.snapshot()
        snapshot.pocket = [PocketSlot(window: late, phase: .pocketed)]
        core.state.adopt(snapshot)
        #expect(core.state.pocket.first?.window == late)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: late, pid: 900_007, appName: "Late")
            )
        )
        #expect(core.state.pocketPhase(of: late) == .pocketed)
        #expect(core.state.workspaces.space(of: late) == nil)
    }
}
