import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The Monocle flip's pure decision (#1391): when it plays, which
/// way it turns, and where the plate starts and lands.
@Suite("Monocle flip plan (#1391)")
struct MonocleFlipPlanTests {
    private static let a = WindowID(1)
    private static let b = WindowID(2)
    private static let c = WindowID(3)
    private static let members = [a, b, c]
    private static let slot = CGRect(x: 10, y: 20, width: 800, height: 600)

    private static func decide(
        current: WindowID = a,
        target: WindowID = b,
        step: Int? = 1,
        orientation: MonocleParams.Orientation = .horizontal,
        targetSize: CGSize = slot.size,
        durationMS: Int = 450,
        enabled: Bool = true,
        reduceMotion: Bool = false
    ) -> MonocleFlipPlan? {
        MonocleFlipPlan.decide(
            current: current,
            target: target,
            members: members,
            step: step,
            orientation: orientation,
            currentFrame: slot,
            targetSize: targetSize,
            durationMS: durationMS,
            enabled: enabled,
            reduceMotion: reduceMotion
        )
    }

    @Test("A directional step plays with the pressed sign")
    func directionalStepPlays() {
        let next = Self.decide(step: 1)
        let previous = Self.decide(current: Self.b, target: Self.a, step: -1)
        #expect(next?.sign == 1)
        #expect(previous?.sign == -1)
    }

    @Test("A wrapped step keeps the pressed direction")
    func wrapKeepsThePressedDirection() {
        // Forward off the end lands on the first: array order
        // says back, the press says forward, and the press wins.
        let plan = Self.decide(current: Self.c, target: Self.a, step: 1)
        #expect(plan?.sign == 1)
    }

    @Test("A named target takes array order")
    func namedTargetTakesArrayOrder() {
        let forward = Self.decide(
            current: Self.a,
            target: Self.c,
            step: nil
        )
        let back = Self.decide(
            current: Self.c,
            target: Self.a,
            step: nil
        )
        #expect(forward?.sign == 1)
        #expect(back?.sign == -1)
    }

    @Test("The axis follows the Monocle orientation")
    func axisFollowsOrientation() {
        #expect(Self.decide(orientation: .horizontal)?.axis == .vertical)
        #expect(Self.decide(orientation: .vertical)?.axis == .horizontal)
    }

    @Test("The plate lands on the target's size, centred")
    func plateLandsCentred() {
        let plan = Self.decide(targetSize: CGSize(width: 400, height: 300))
        #expect(plan?.from == Self.slot)
        #expect(plan?.to == CGRect(x: 210, y: 170, width: 400, height: 300))
        #expect(plan?.cover == Self.slot)
    }

    @Test("Timing derives from the duration and the fixed fades")
    func timing() {
        let plan = Self.decide(durationMS: 450)
        #expect(plan?.duration == 0.45)
        // The focus lands once the blur covers the surface, at
        // the end of the fade-in — never later.
        #expect(plan?.landing == MonocleFlipPlan.fadeIn)
        #expect(
            plan?.total
                == MonocleFlipPlan.fadeIn + 0.45 + MonocleFlipPlan.fadeOut
        )
    }

    @Test("Stands down: disabled, Reduce Motion, same target, non-member")
    func standsDown() {
        #expect(Self.decide(enabled: false) == nil)
        #expect(Self.decide(reduceMotion: true) == nil)
        #expect(Self.decide(target: Self.a) == nil)
        #expect(Self.decide(target: WindowID(9)) == nil)
        #expect(Self.decide(current: WindowID(9)) == nil)
    }
}
