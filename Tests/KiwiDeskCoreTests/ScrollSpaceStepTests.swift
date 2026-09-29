import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥⌘ + scroll (#1519, rulings 2026-09-28/29): one Space per
/// swipe or wheel notch, in the Space order of the screen under the
/// pointer, stopping at the ends, never warping — and a spinning
/// wheel steps once (`ScrollStepMeterTests`).
@Suite("Scroll Space step gesture", .serialized)
@MainActor
struct ScrollSpaceStepTests {
    private static let chord: ScrollChord = [.control, .option, .command]
    private static let displayA = DisplayID(1)
    private static let displayB = DisplayID(2)

    /// Spaces 1–3 on display A and 7–8 on display B, a window in
    /// each; Space `shown` active. The session answers `under`.
    private func makeCore(
        shown: String = "2",
        under display: DisplayID = displayA
    ) -> (KiwiCore, ScrollSpaceStepSession) {
        let core = makeTestCore()
        let spaces: [(String, DisplayID)] = [
            ("1", Self.displayA), ("2", Self.displayA),
            ("3", Self.displayA), ("7", Self.displayB),
            ("8", Self.displayB),
        ]
        for (index, display) in [Self.displayA, Self.displayB].enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: display,
                    name: "D\(index)",
                    frame: CGRect(
                        x: 1600 * CGFloat(index),
                        y: 0,
                        width: 1600,
                        height: 1000
                    )
                )
            )
        }
        for (index, (raw, display)) in spaces.enumerated() {
            core.state.workspaces.assign(SpaceID(raw), to: display)
            let id = WindowID(UInt32(index + 1))
            core.state.windows.upsert(
                ManagedWindow(id: id, pid: pid_t(index + 1), appName: raw)
            )
            core.state.workspaces.add(id, to: SpaceID(raw))
            core.state.workspaces.focus(id, in: SpaceID(raw))
        }
        core.state.workspaces.activate(SpaceID(shown))
        let session = ScrollSpaceStepSession()
        session.displayAt = { _ in display }
        return (core, session)
    }

    private func event(
        _ kind: ScrollGestureEvent.Kind,
        dx: Double = 0,
        dy: Double = 0,
        input: ScrollGestureEvent.Input = .trackpad,
        momentum: Bool = false,
        time: Double = 0
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: Self.chord,
            kind: kind,
            input: input,
            delta: CGVector(dx: dx, dy: dy),
            momentum: momentum,
            location: .zero,
            time: time
        )
    }

    private func swipe(
        _ core: KiwiCore,
        _ session: ScrollSpaceStepSession,
        dx: Double,
        events: Int = 1
    ) {
        core.handleScrollSpaceStep(event(.began), session: session)
        for _ in 0..<events {
            core.handleScrollSpaceStep(
                event(.changed, dx: dx),
                session: session
            )
        }
        core.handleScrollSpaceStep(event(.ended), session: session)
    }

    private func notches(
        _ core: KiwiCore,
        _ session: ScrollSpaceStepSession,
        at times: [Double],
        dy: Double = -10
    ) {
        core.handleScrollSpaceStep(
            event(.began, input: .wheel, time: times[0]),
            session: session
        )
        for time in times {
            core.handleScrollSpaceStep(
                event(.changed, dy: dy, input: .wheel, time: time),
                session: session
            )
        }
        core.handleScrollSpaceStep(
            event(.ended, input: .wheel, time: times.last! + 0.25),
            session: session
        )
    }

    private func shown(_ core: KiwiCore) -> String? {
        core.state.workspaces.activeSpace?.raw
    }

    @Test("a swipe steps one Space, against the fingers")
    func oneSpacePerSwipe() {
        let (core, session) = makeCore(shown: "1")
        // Long swipes are the window step's alone (#1519 ruling):
        // turned on, a long swipe still steps one Space.
        var base = ScrollGestureBase.defaults
        base.longSwipes = true
        base.stepDistance = 10
        core.applyScrollGestures(base: base, profile: nil)
        // Fingers left: content left, the NEXT Space comes in.
        swipe(core, session, dx: -80, events: 6)
        #expect(shown(core) == "2")
        swipe(core, session, dx: 80)
        #expect(shown(core) == "1")
    }

    @Test("the glide after a lift never steps")
    func glideNeverCounts() {
        let (core, session) = makeCore(shown: "1")
        core.handleScrollSpaceStep(event(.began), session: session)
        // Too short to step: only the glide could carry it.
        core.handleScrollSpaceStep(event(.changed, dx: -5), session: session)
        for _ in 0..<20 {
            core.handleScrollSpaceStep(
                event(.changed, dx: -900, momentum: true),
                session: session
            )
        }
        #expect(shown(core) == "1")
    }

    @Test("a wheel steps once per notch clicked one at a time")
    func onePerNotch() {
        let (core, session) = makeCore(shown: "1")
        notches(core, session, at: [0, 0.2])
        #expect(shown(core) == "3")
    }

    @Test("a fast roll or a spinning wheel steps once")
    func spinStepsOnce() {
        let (core, session) = makeCore(shown: "1")
        notches(core, session, at: stride(from: 0, to: 1, by: 0.02).map { $0 })
        #expect(shown(core) == "2")
        // A new burst after the wheel rested steps again.
        notches(core, session, at: [2])
        #expect(shown(core) == "3")
    }

    @Test("the first and last Space stop the step, with a bump")
    func stopsAtTheEnds() {
        let (core, session) = makeCore(shown: "3")
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        swipe(core, session, dx: -80)
        #expect(shown(core) == "3")
        #expect(bumps == [.right])
        let (first, firstSession) = makeCore(shown: "1")
        var firstBumps: [Direction] = []
        first.borders.deadEndProbe = { firstBumps.append($1) }
        swipe(first, firstSession, dx: 80)
        #expect(shown(first) == "1")
        #expect(firstBumps == [.left])
    }

    @Test("an empty Space at the end has no ring, and says nothing")
    func emptyEndIsSilent() {
        let (core, session) = makeCore(shown: "3")
        core.state.apply(.windowDestroyed(WindowID(3), wasMinimized: false))
        var bumps = 0
        core.borders.deadEndProbe = { _, _ in bumps += 1 }
        swipe(core, session, dx: -80)
        #expect(shown(core) == "3")
        #expect(bumps == 0)
    }

    @Test("it steps the Spaces of the screen under the pointer")
    func screenUnderPointer() {
        let (core, session) = makeCore(shown: "2", under: Self.displayB)
        swipe(core, session, dx: -80)
        #expect(shown(core) == "8")
        #expect(core.state.workspaces.activeSpace(on: Self.displayA) == "2")
    }

    @Test("no step moves the pointer, where focus_space does")
    func noWarp() {
        let (core, session) = makeCore(shown: "1")
        core.tiler.settings.mouse.followsFocus = true
        var warps = 0
        core.pointerWarp = { _ in warps += 1 }
        swipe(core, session, dx: -80)
        #expect(shown(core) == "2")
        #expect(warps == 0)
        // The negative control: the command's own switch warps.
        core.execute("focus_space", args: [.string("3")])
        #expect(warps == 1)
    }

    /// Bootstrap wires the consumer, so the tap takes its chord;
    /// unwired, the tap would let ⌃⌥⌘ + scroll reach the window.
    @Test("bootstrap wires the step consumer")
    func wired() {
        let core = makeTestCore()
        let tap = RecordingTap()
        core.mouse.scroll.makeTap = { _ in tap }
        var base = ScrollGestureBase.defaults
        base.pan = []
        core.applyScrollGestures(base: base, profile: nil)
        core.mouse.scroll.start()
        #expect(tap.chords == [Self.chord])
    }
}

private final class RecordingTap: ScrollTapHandle {
    var chords: Set<ScrollChord> = []
    func setChords(_ chords: Set<ScrollChord>) { self.chords = chords }
    func stop() {}
}
