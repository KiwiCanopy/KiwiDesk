import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private final class MovingReader: TouchReaderHandle {
    var travel: TouchTravel.Reading?
    func stop() {}
}

/// The pan hands the meter the touch reader's travel (#1873 ▸
/// Ruling 2026-11-16), read through `MouseTracker.trackpad`: a
/// finger move worth a step steps although its point deltas are
/// far short of the points fallback, which a call site passing no
/// reading would count.
@Suite("Scroll pan finger travel wiring", .serialized)
@MainActor
struct ScrollPanFingerWiringTests {
    private func event(
        _ kind: ScrollGestureEvent.Kind,
        _ dx: Double = 0
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: [.control, .option],
            kind: kind,
            input: .trackpad,
            delta: CGVector(dx: dx, dy: 0),
            momentum: false,
            location: .zero,
            time: 0
        )
    }

    @Test("a finger move steps where its points would not")
    func readingReachesTheMeter() throws {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        for id in 1...4 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = try #require(core.state.workspaces.space(of: WindowID(1)))
        core.execute("set_mode", args: [.string(space.raw), .string("grid")])
        core.execute("set_focus_wrap", args: [.string("this_screen")])
        core.state.workspaces.focus(WindowID(1), in: space)
        var base = ScrollGestureBase.defaults
        base.longSwipes = true
        base.stepLength = 10
        core.applyScrollGestures(base: base, profile: nil)
        let reader = MovingReader()
        core.mouse.trackpad.makeReader = { _, _ in reader }
        core.mouse.trackpad.start()
        defer { core.mouse.trackpad.stop() }
        #expect(core.mouse.trackpad.isReading)

        let session = ScrollPanSession()
        session.spaceAt = { _, _ in space }
        reader.travel = TouchTravel.Reading(sum: .zero, source: 7)
        core.handleScrollPan(
            event(.began),
            session: session,
            directional: true
        )
        // The latch: 1 → 2.
        core.handleScrollPan(
            event(.changed, 30),
            session: session,
            directional: true
        )
        // 10 mm of finger on 5 pt of points: 2 → 1, wrapping.
        reader.travel = TouchTravel.Reading(
            sum: CGVector(dx: 10, dy: 0),
            source: 7
        )
        core.handleScrollPan(
            event(.changed, 5),
            session: session,
            directional: true
        )
        core.handleScrollPan(
            event(.ended),
            session: session,
            directional: true
        )
        #expect(core.state.workspaces[space]?.focused == WindowID(1))
    }
}
