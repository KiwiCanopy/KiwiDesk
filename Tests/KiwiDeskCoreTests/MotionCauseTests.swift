import Foundation
import Testing

@testable import KiwiDeskCore

/// Whose motion a frame write belongs to (#804 ▸ Ruling 1–3): the
/// scope a KiwiDesk control opens, a hold-glide step, and a tail a
/// call schedules — which stays `user` but late. Behaviour-neutral
/// until the gate reads it; `MotionScopeCensusTests` holds who opens
/// the scope.
@Suite("Motion cause scope (#804)", .serialized)
@MainActor
struct MotionCauseTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        let now = Date(timeIntervalSinceReferenceDate: 2_000_000)
        core.wallClock = { now }
        return core
    }

    private var pressed: Date {
        Date(timeIntervalSinceReferenceDate: 2_000_000)
    }

    @Test("Unlabelled motion is ambient")
    func unsetIsAmbient() {
        #expect(makeCore().motionCause == .ambient)
    }

    @Test("A control's call is user motion, and only inside it")
    func userScopeIsScoped() {
        let core = makeCore()
        let inside = core.withUserMotion { core.motionCause }
        #expect(inside == .user(pressedAt: pressed, late: false))
        #expect(core.motionCause == .ambient)
    }

    @Test("A nested opener keeps the outer press time")
    func nestedKeepsPressTime() {
        let core = makeCore()
        let inner: MotionCause = core.withUserMotion {
            core.wallClock = { Date(timeIntervalSinceReferenceDate: 9) }
            return core.withUserMotion { core.motionCause }
        }
        #expect(inner == .user(pressedAt: pressed, late: false))
    }

    @Test("A hold-glide step is a press of its own")
    func glideStepIsUser() {
        let core = makeCore()
        core.keys.holdGlide.isApplyingGlideStep = true
        defer { core.keys.holdGlide.isApplyingGlideStep = false }
        #expect(core.motionCause == .user(pressedAt: pressed, late: false))
    }

    @Test("A hotkey's fire is user motion")
    func hotkeyIsUser() {
        let core = makeCore()
        var seen: MotionCause?
        core.keys.simulatingFire { seen = core.motionCause }
        #expect(seen == .user(pressedAt: pressed, late: false))
    }

    /// The frame applier reads the same full cause the reader
    /// folds, so the gate at the door sees a hotkey too.
    @Test("The frame applier's reading is the core's")
    func applierReadsTheFold() {
        let core = makeCore()
        var seen: MotionCause?
        core.keys.simulatingFire { seen = core.tiler.applier.cause() }
        #expect(seen == .user(pressedAt: pressed, late: false))
        #expect(core.tiler.applier.cause() == .ambient)
    }

    /// A burst past its bound runs inside the caller's own call:
    /// a carried slot keeps that cause, an uncarried one is ambient.
    @Test("The bounded burst path keeps the per-slot ruling")
    func boundedBurstKeepsRuling() {
        let core = makeCore()
        var carried: MotionCause?
        var uncarried: MotionCause?
        core.withUserMotion {
            core.deferred.schedule(
                .spaceSettle,
                after: .seconds(5),
                maxWait: .zero
            ) { carried = core.motionCause }
            core.deferred.schedule(
                .barTitleRefresh,
                after: .seconds(5),
                maxWait: .zero
            ) { uncarried = core.motionCause }
        }
        #expect(carried == .user(pressedAt: pressed, late: false))
        #expect(uncarried == .ambient)
    }

    @Test("A tail a control's call schedules is user motion, late")
    func carriedTailIsLate() async {
        let core = makeCore()
        var seen: MotionCause?
        core.withUserMotion {
            core.deferred.schedule(.spaceSettle, after: .zero) {
                seen = core.motionCause
            }
        }
        await core.deferred.task(for: .spaceSettle)?.value
        #expect(seen == .user(pressedAt: pressed, late: true))
        #expect(core.motionCause == .ambient)
    }

    @Test("A slot no one press owns runs ambient, whoever scheduled it")
    func uncarriedSlotIsAmbient() async {
        let core = makeCore()
        var seen: MotionCause?
        core.withUserMotion {
            core.deferred.schedule(.adoptionHeal, after: .zero) {
                seen = core.motionCause
            }
        }
        await core.deferred.task(for: .adoptionHeal)?.value
        #expect(seen == .ambient)
    }

    @Test("An ambient caller's tail stays ambient")
    func ambientTailStaysAmbient() async {
        let core = makeCore()
        var seen: MotionCause?
        core.deferred.schedule(.spaceSettle, after: .zero) {
            seen = core.motionCause
        }
        await core.deferred.task(for: .spaceSettle)?.value
        #expect(seen == .ambient)
    }
}
