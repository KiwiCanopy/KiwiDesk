import AppKit
import Foundation
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The pocket's rise has one 0–1 progress, read where it is drawn
/// (#3383): each transition removes the running animation and adds
/// one lasting the distance left times its pace — a rise 0.25 s, a
/// hurry 0.15 s, a sink 0.2 s — and a risen pocket going to rest
/// sinks. A headless run draws nothing, so the drawn rise is seeded
/// as the running animation's start, which `pocketRiseShown` reads
/// with no presentation layer.
@Suite(
    "Pocket rise sequence (#3383)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketRiseSequenceTests {
    typealias Rig = PocketApproachTests.Rig

    private func rig() throws -> Rig {
        try PocketApproachTests().rig()
    }

    private func view(_ rig: Rig) throws -> PocketPlateView {
        try #require(rig.core.pocketPlate.view(on: rig.display))
    }

    private func running(_ view: PocketPlateView) -> CABasicAnimation? {
        view.pocket.layer?.animation(forKey: BarMotion.pocketRiseKey)
            as? CABasicAnimation
    }

    /// Seeds the pocket as drawn `done` of the way up.
    static func seed(
        _ view: PocketPlateView,
        _ rig: Rig,
        done: CGFloat
    ) throws {
        let spec = try #require(rig.spec)
        let edge = try #require(spec.handle)
        let start = BarMotion.pocketRiseStart(edge: edge, side: spec.risenSide)
        var shown = CATransform3DIdentity
        shown.m41 = start.m41 * (1 - done)
        shown.m42 = start.m42 * (1 - done)
        let held = CABasicAnimation(keyPath: "transform")
        held.fromValue = NSValue(caTransform3D: shown)
        held.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        held.duration = 1
        view.pocket.layer?.add(held, forKey: BarMotion.pocketRiseKey)
    }

    @Test("lingering waits, then rises over 0.25 s")
    func riseShape() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        let target = try #require(rig.target)
        rig.move(to: try PocketApproachTests().nearTab(target))
        let scrub = try #require(running(try view(rig)))
        #expect(scrub.beginTime > 0)
        #expect(abs(scrub.duration - PocketRiseTimeline.span) < 1e-6)
    }

    @Test("a hurry runs the distance left at the fast pace")
    func hurryFromWhereItIs() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        let target = try #require(rig.target)
        rig.move(to: try PocketApproachTests().nearTab(target))
        let view = try view(rig)
        try Self.seed(view, rig, done: 0.4)
        rig.pointer.now += ShelfReveal.revealDelay + 0.1
        rig.move(to: try PocketApproachTests().onTab(target))
        let hurry = try #require(running(view))
        // Read off the drawn rise, at once, no wait again.
        #expect(hurry.beginTime == 0)
        #expect(abs(hurry.duration - 0.6 * PocketRiseTimeline.fastSpan) < 1e-3)
    }

    @Test("a hurry on a rise already up keeps it drawn up")
    func upRiseStays() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        let target = try #require(rig.target)
        rig.move(to: try PocketApproachTests().nearTab(target))
        let view = try view(rig)
        try Self.seed(view, rig, done: 1)
        rig.pointer.now += ShelfReveal.revealDelay + 0.1
        rig.move(to: try PocketApproachTests().onTab(target))
        // Nothing left to run: what stood there stays, never the
        // kiwis the open would then rise from.
        let held = try #require(running(view))
        #expect(held.duration == 1)
    }

    @Test("an open after the rise is drawn up springs from up")
    func openFromUp() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        rig.move(
            to: try PocketApproachTests().nearTab(try #require(rig.target))
        )
        let view = try view(rig)
        // The rise ran out and nothing runs: the pocket stands up.
        view.pocket.layer?.removeAllAnimations()
        rig.timers.fireAll()
        rig.pass()
        #expect(rig.spec?.risen == true)
        let spring = try #require(
            view.pocket.layer?.animation(forKey: BarMotion.pocketRiseKey)
                as? CASpringAnimation
        )
        let from = try #require(
            (spring.fromValue as? NSValue)?.caTransform3DValue
        )
        #expect(CATransform3DIsIdentity(from))
    }

    @Test("the whole mark ends a sink that runs")
    func wholeEndsTheSink() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        rig.move(
            to: try PocketApproachTests().nearTab(try #require(rig.target))
        )
        let view = try view(rig)
        try Self.seed(view, rig, done: 0.5)
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        #expect(view.sinking)
        rig.core.execute(
            "kiwishelf.set_pocket_visibility",
            args: [.string("always")]
        )
        rig.pass()
        #expect(rig.spec?.whole == true)
        #expect(!view.sinking)
        #expect(running(view) == nil)
    }

    @Test("a leave sinks the distance up, in the risen room")
    func leaveSinksFromWhereItIs() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        var landings: [() -> Void] = []
        rig.core.pocketPlate.afterLeave = { _, body in landings.append(body) }
        let rest = try #require(rig.spec)
        rig.move(
            to: try PocketApproachTests().nearTab(try #require(rig.target))
        )
        let view = try view(rig)
        try Self.seed(view, rig, done: 0.5)
        let room = view.frame.size
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        let sink = try #require(running(view))
        #expect(abs(sink.duration - 0.5 * BarMotion.pocketSinkSpan) < 1e-3)
        #expect(view.sinking)
        #expect(view.frame.size == room)
        landings.forEach { $0() }
        #expect(!view.sinking)
        #expect(view.frame.size == rest.frame.size)
    }

    @Test("a leave before the rise started gives the room back at once")
    func unstartedLeaveSinksNothing() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        let rest = try #require(rig.spec)
        rig.move(
            to: try PocketApproachTests().nearTab(try #require(rig.target))
        )
        let view = try view(rig)
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        #expect(!view.sinking)
        #expect(view.frame.size == rest.frame.size)
    }

    @Test("a risen pocket going to rest sinks")
    func risenToRestSinks() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        var landings: [() -> Void] = []
        rig.core.pocketPlate.afterLeave = { _, body in landings.append(body) }
        rig.move(
            to: try PocketApproachTests().nearTab(try #require(rig.target))
        )
        rig.timers.fireAll()
        rig.pass()
        #expect(rig.spec?.risen == true)
        let view = try view(rig)
        let room = view.frame.size
        // Landed: no rise runs, the pocket stands risen.
        view.pocket.layer?.removeAllAnimations()
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        rig.timers.fireAll()
        rig.pass()
        let rest = try #require(rig.spec)
        #expect(!rest.risen)
        let sink = try #require(running(view))
        #expect(abs(sink.duration - BarMotion.pocketSinkSpan) < 1e-3)
        #expect(view.sinking)
        // It sinks in the risen room, which its landing gives back.
        #expect(view.frame.size == room)
        landings.forEach { $0() }
        #expect(!view.sinking)
        #expect(view.frame.size == rest.frame.size)
    }

    @Test("a view's sink ends only on its own token")
    func endSinkTakesItsOwn() throws {
        // A sink plays only with motion on, which another suite's
        // core may have left off (`ReduceMotion.kiwiDesk`).
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let view = PocketPlateView(
            frame: CGRect(x: 0, y: 0, width: 80, height: 80)
        )
        view.wantsLayer = true
        let up = PocketPlateView.Before(risen: true)
        let first = view.stand(
            handle: .bottom,
            risen: false,
            side: 40,
            before: up
        )
        #expect(first > 0)
        let older = try #require(view.sink)
        view.stand(handle: .bottom, risen: false, side: 40, before: up)
        let newer = try #require(view.sink)
        #expect(older != newer)
        view.endSink(older)
        #expect(view.sink == newer)
        view.endSink(newer)
        #expect(view.sink == nil)
    }

    @Test("an older sink's landing ends no newer sink")
    func landingIsTheSinksOwn() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        var landings: [() -> Void] = []
        rig.core.pocketPlate.afterLeave = { _, body in landings.append(body) }
        let target = try #require(rig.target)
        let near = try PocketApproachTests().nearTab(target)
        rig.move(to: near)
        let view = try view(rig)
        try Self.seed(view, rig, done: 0.5)
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        let first = try #require(view.sink)
        // Back and away again: a second sink.
        rig.move(to: near)
        try Self.seed(view, rig, done: 0.5)
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        let second = try #require(view.sink)
        #expect(first != second)
        landings.first?()
        #expect(view.sink == second)
    }
}
