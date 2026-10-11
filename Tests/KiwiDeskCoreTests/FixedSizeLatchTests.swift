import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A fixed size (#2070) is judged at adoption: a recheck never
/// floats a tiled window on a disabled zoom button alone — a sheet
/// can grey it for a moment — while a window adopted fixed-size
/// keeps that reason through its rechecks.
@Suite("Fixed-size latch (#2070)")
@MainActor
struct FixedSizeLatchTests {
    private let id = WindowID(41)
    private let pid: pid_t = 99_999

    private func recheck(
        _ core: KiwiCore,
        _ reason: AutoFloatReason?
    ) -> [KiwiEvent] {
        var events: [KiwiEvent] = []
        // Only the float flag is the subject here.
        core.eventLoop.detectedFullscreen[id] = false
        core.eventLoop.onEvent = { events.append($0) }
        core.eventLoop.recheckFloat(
            id: id,
            pid: pid,
            app: AppRef(pid: pid),
            reading: TrackedReading(
                fullscreen: false,
                subrole: "",
                frame: .zero,
                autoReason: reason,
                traits: nil
            )
        )
        return events
    }

    @Test("a recheck never floats a tiled window as fixed-size")
    func tiledStaysTiled() {
        let core = makeTestCore()
        core.eventLoop.detectedFloating[id] = .tiles
        let events = recheck(core, .fixedSize)
        #expect(core.eventLoop.detectedFloating[id] == .tiles)
        #expect(events.isEmpty)
    }

    @Test("a window adopted fixed-size keeps its reason")
    func adoptedStays() {
        let core = makeTestCore()
        core.eventLoop.detectedFloating[id] = .floats(.fixedSize)
        let events = recheck(core, .fixedSize)
        #expect(core.eventLoop.detectedFloating[id] == .floats(.fixedSize))
        #expect(events.isEmpty)
    }
}
