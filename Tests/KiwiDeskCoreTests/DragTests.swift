import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("DragCoordinator", .serialized)
@MainActor
struct DragCoordinatorTests {
    @Test("Rapid moves settle into exactly one drag end")
    func debounce() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        var ended: [(WindowID, CGRect)] = []
        drag.onDragEnd = { id, frame in
            ended.append((id, frame))
        }
        let id = WindowID(1)
        for x in 1...3 {
            drag.windowMoved(
                id,
                frame: CGRect(
                    x: CGFloat(x * 100),
                    y: 0,
                    width: 10,
                    height: 10
                )
            )
        }
        // Poll instead of a fixed sleep: under full-suite
        // load the settle task can get main-actor time late.
        let deadline = ContinuousClock.now + .seconds(5)
        while ended.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        // Grace window so a wrong second fire would show up.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(ended.count == 1)
        #expect(ended.first?.1.minX == 300)
    }

    @Test("Animation-driven moves never count as drags")
    func animationFiltered() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        drag.isAnimating = { _ in true }
        var ended = 0
        drag.onDragEnd = { _, _ in ended += 1 }
        drag.windowMoved(WindowID(1), frame: .zero)
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(ended == 0)
    }

    @Test("Cancel drops a pending drag (window closed)")
    func cancelPending() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        var ended = 0
        drag.onDragEnd = { _, _ in ended += 1 }
        drag.windowMoved(WindowID(1), frame: .zero)
        drag.cancel(WindowID(1))
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(ended == 0)
    }
}

@Suite("Drag drop resolution", .serialized)
@MainActor
struct DragDropTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-drag-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 1,
                    appName: "App\(raw)"
                )
            )
        )
    }

    @Test("Dropping onto another slot swaps the windows")
    func swapOnDrop() throws {
        // Needs a real screen for slot geometry.
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let targetSlot = try #require(slots[WindowID(2)])

        core.handleDragEnd(WindowID(1), frame: targetSlot)
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(2), WindowID(1)]
        )
    }

    @Test("Dropping into nowhere keeps the order (snap back)")
    func snapBack() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)

        core.handleDragEnd(
            WindowID(1),
            frame: CGRect(
                x: -9000,
                y: -9000,
                width: 100,
                height: 100
            )
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1), WindowID(2)]
        )
    }
}
