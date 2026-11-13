import AppKit
import ApplicationServices
import CoreGraphics
import Testing
import os

@testable import KiwiDeskCore

/// A grab's frame writes are latest-wins per window (#3266): over
/// a stalled app queue, a run of grab events leaves one waiting
/// set, which writes the newest frame, and any other instant set
/// retires a waiting grab frame so it never lands after a newer
/// ask. The element is the test process's own, so every block
/// rides the main queue, which stays stalled until `drain`.
@Suite("Modifier grab writes are latest-wins (#3266)", .serialized)
@MainActor
struct ModifierGrabLatestWinsTests {
    private static let window = WindowID(43)
    private static let frame = CGRect(x: 100, y: 100, width: 400, height: 300)

    private final class Log: Sendable {
        let frames = OSAllocatedUnfairLock<[CGRect]>(initialState: [])
        let calls = OSAllocatedUnfairLock<Int>(initialState: 0)
        func add(_ frame: CGRect) {
            frames.withLock { $0.append(frame) }
            calls.withLock { $0 += 1 }
        }
        func touch() { calls.withLock { $0 += 1 } }
        var written: [CGRect] { frames.withLock { $0 } }
        var count: Int { calls.withLock { $0 } }
    }

    private func writer(_ log: Log) -> FrameWriter {
        FrameWriter(
            setFrame: { frame, _ in log.add(frame) },
            setPosition: { _, _ in log.touch() },
            writeEUI: { _, _ in },
            setSize: { _, _ in log.touch() }
        )
    }

    private func make(_ log: Log) -> KiwiCore {
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: Self.window, pid: 900_043, appName: "App")
            )
        )
        core.state.apply(.windowMoved(Self.window, Self.frame))
        core.frontStack = {
            [
                KiwiCore.FrontWindow(
                    number: CGWindowID(Self.window.raw),
                    pid: 900_043,
                    layer: 0,
                    frame: Self.frame
                )
            ]
        }
        let element = AXUIElementCreateApplication(getpid())
        core.tiler.elementProvider = { _ in element }
        core.tiler.applier.writer = writer(log)
        core.tiler.applier.ownWindowMove = { _, _, _ in false }
        core.mouse.pointer.start()
        return core
    }

    private func send(
        _ core: KiwiCore,
        _ phase: ModifierGrabEvent.Phase,
        at point: CGPoint
    ) {
        core.mouse.pointer.receive(
            PointerTapDelivery(
                grab: [
                    ModifierGrabEvent(
                        phase: phase,
                        action: .resize,
                        start: .drag,
                        chord: ModifierDragSettings.defaults.grabs
                            .first { $0.action == .resize }?.chord ?? [],
                        location: point,
                        time: 0
                    )
                ],
                reenabled: false
            )
        )
    }

    /// Every block queued so far has run: the main queue is serial.
    private func drain() async {
        await withCheckedContinuation { done in
            DispatchQueue.main.async { done.resume() }
        }
    }

    @Test("N grab events over a stalled queue write at most twice")
    func grabCoalesces() async throws {
        let log = Log()
        let core = make(log)
        // Bottom-right cell: the bottom-right corner moves.
        send(core, .began, at: CGPoint(x: 480, y: 390))
        for step in 1...20 {
            let d = CGFloat(step * 5)
            send(core, .moved, at: CGPoint(x: 480 + d, y: 390 + d))
        }
        let last = try #require(core.modifierGrab.session?.last)
        #expect(last.width > Self.frame.width)
        await drain()
        #expect(log.count >= 1)
        #expect(log.count <= 2)
        #expect(log.written.last == last)
    }

    @Test("Another instant set retires a waiting grab frame")
    func newerSetWins() async {
        let log = Log()
        let core = make(log)
        let applier = core.tiler.applier
        let grabbed = Self.frame.offsetBy(dx: 10, dy: 0)
        let placed = Self.frame.offsetBy(dx: 50, dy: 0)
        applier.applyInstant(
            Self.window,
            grabbed,
            setSize: true,
            latestWins: true
        )
        applier.applyInstant(Self.window, placed, setSize: true)
        await drain()
        #expect(log.written == [placed])
    }
}
