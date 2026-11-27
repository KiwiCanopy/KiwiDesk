import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The wear's drop in Core Animation (#3700): it sits above the
/// picker, takes no click, and each step of the reveal hands the
/// render server one animation, the drop keeping where it lands.
/// Under Reduce Motion it never moves. Main actor for the controller
/// and its panel; each driven test shows one panel, as
/// `LookPickerPanelTests` does.
@Suite("Look picker drop (#3700)", .serialized)
@MainActor
struct LookPickerDropTests {
    /// A shown controller whose timers wait in `later`, keyed by
    /// their delay, and whose commit hook runs at once.
    private func shown(
        reduceMotion: Bool
    ) -> (LookPickerController, () -> [(TimeInterval, @MainActor () -> Void)])
    {
        let controller = LookPickerController(core: makeTestCore())
        var later: [(TimeInterval, @MainActor () -> Void)] = []
        controller.after = { delay, work in later.append((delay, work)) }
        controller.afterCommit = { $0() }
        controller.reduceMotion = { reduceMotion }
        controller.handBack.nextTurn = { $0() }
        controller.handBack.orderFrontKey = { $0.orderFrontRegardless() }
        controller.show()
        return (controller, { later })
    }

    private func wear(_ controller: LookPickerController) throws {
        let model = try #require(controller.model)
        while model.selection == model.wornIndex {
            model.handle(.step(1), repeated: false)
        }
        model.wearSelected()
    }

    @Test("the drop sits above the picker and takes no click")
    func dropIsAbove() throws {
        let (controller, _) = shown(reduceMotion: false)
        defer { controller.close() }
        let content = try #require(
            controller.panel?.contentView as? LookPickerContent
        )
        let drop = try #require(controller.dropView)
        #expect(content.subviews.last === drop)
        #expect(content.subviews.first === content.picker)
        #expect(drop.hitTest(NSPoint(x: 10, y: 10)) == nil)
    }

    @Test("each step hands the layers one animation and keeps its end")
    func stepsAnimate() throws {
        let (controller, later) = shown(reduceMotion: false)
        defer { controller.close() }
        let view = try #require(controller.dropView)
        #expect(view.drop.opacity == 0)
        try wear(controller)
        #expect(controller.revealing)
        #expect(view.drop.opacity == 1)
        let backing = try #require(controller.panel?.backingScaleFactor)
        #expect(view.drop.contentsScale == backing)
        #expect(view.ripple.contentsScale == backing)
        // It lands with its middle on the card's centre, the anchor at
        // its bottom, in the view's unflipped points.
        let landing = controller.geometry.landing
        let height = view.bounds.height
        #expect(
            view.drop.position
                == CGPoint(
                    x: landing.x,
                    y: height - landing.y - LookPickerDropView.height / 2
                )
        )
        #expect(
            view.ripple.position
                == CGPoint(x: landing.x, y: height - landing.y)
        )
        #expect(view.drop.animation(forKey: "position") != nil)
        #expect(view.drop.animation(forKey: "opacity") != nil)
        let steps = later()
        let squash = try #require(
            steps.first { $0.0 == LookPickerReveal.fall }
        )
        squash.1()
        #expect(view.drop.animation(forKey: "transform") is CASpringAnimation)
        #expect(view.drop.transform.m11 == 1.3)
        let sinkAt = LookPickerReveal.fall + LookPickerReveal.squashHold
        let sink = try #require(steps.first { $0.0 == sinkAt })
        sink.1()
        #expect(view.drop.opacity == 0)
        #expect(view.ripple.animation(forKey: "path") != nil)
        #expect(view.ripple.opacity == 0)
    }

    @Test("under Reduce Motion the drop never moves")
    func reduceMotionStill() throws {
        let (controller, later) = shown(reduceMotion: true)
        defer { controller.close() }
        let view = try #require(controller.dropView)
        try wear(controller)
        #expect(controller.revealing)
        later().forEach { $0.1() }
        #expect(view.drop.animationKeys() == nil)
    }

    @Test("a gated step lands at its end with no animation")
    func gatedStepsLand() {
        let view = LookPickerDropView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 600)
        )
        view.prepare(landingAt: CGPoint(x: 400, y: 300))
        view.fall(reduceMotion: true)
        #expect(view.drop.opacity == 1)
        view.squash(reduceMotion: true)
        #expect(view.drop.transform.m11 == 1.3)
        view.sink(reduceMotion: true)
        #expect(view.drop.opacity == 0)
        #expect(view.drop.animationKeys() == nil)
        #expect(view.ripple.animationKeys() == nil)
    }
}
