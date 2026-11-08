import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pointer tap's pure decision (#2447): a grab begins only on
/// its exact chord, owns the button stream it began to the
/// release, and a hover grab ends when a key is let go.
@Suite("PointerTapRouter")
struct PointerTapRouterTests {
    private static let moveChord: ScrollChord = [.control, .command]
    private static let resizeChord: ScrollChord = [.control, .option]

    private func router(
        _ settings: ModifierDragSettings = .defaults
    ) -> PointerTapRouter {
        var router = PointerTapRouter()
        router.snapshot = PointerTapSnapshot(grab: settings)
        return router
    }

    private func sample(
        _ kind: PointerSample.Kind,
        _ chord: ScrollChord,
        x: CGFloat = 10
    ) -> PointerSample {
        PointerSample(kind: kind, location: CGPoint(x: x, y: 5), chord: chord)
    }

    @Test("a press on the move chord is swallowed and begins a move")
    func pressBegins() {
        var r = router()
        let routed = r.route(sample(.leftDown, Self.moveChord), now: 1)
        #expect(routed.swallow)
        #expect(routed.grab.map(\.phase) == [.began])
        #expect(routed.grab.first?.action == .move)
        #expect(routed.grab.first?.start == .drag)
    }

    @Test("the resize chord begins a resize")
    func resizeBegins() {
        var r = router()
        let routed = r.route(sample(.leftDown, Self.resizeChord), now: 1)
        #expect(routed.swallow)
        #expect(routed.grab.first?.action == .resize)
    }

    @Test("a plain press, or a wider chord, passes untouched")
    func otherPressesPass() {
        var r = router()
        #expect(r.route(sample(.leftDown, []), now: 1) == .pass)
        #expect(
            r.route(sample(.leftDown, [.control, .command, .shift]), now: 1)
                == .pass
        )
        #expect(r.owner == nil)
    }

    @Test("the grab owns its stream to the release, chord or not")
    func ownsTheStream() {
        var r = router()
        _ = r.route(sample(.leftDown, Self.moveChord), now: 1)
        // Letting the keys go mid-drag keeps the grab: the press
        // began it, the release ends it.
        let drag = r.route(sample(.leftDragged, [], x: 30), now: 2)
        #expect(drag.swallow)
        #expect(drag.grab.map(\.phase) == [.moved])
        #expect(drag.grab.first?.location == CGPoint(x: 30, y: 5))
        let up = r.route(sample(.leftUp, [], x: 40), now: 3)
        #expect(up.swallow)
        #expect(up.grab.map(\.phase) == [.ended])
        #expect(r.owner == nil)
        // The next drag is the app's.
        #expect(r.route(sample(.leftDragged, []), now: 4) == .pass)
    }

    @Test("a down with no up between ends the old grab first")
    func lostUpRestarts() {
        var r = router()
        _ = r.route(sample(.leftDown, Self.moveChord), now: 1)
        let again = r.route(sample(.leftDown, Self.resizeChord), now: 2)
        #expect(again.grab.map(\.phase) == [.ended, .began])
        #expect(again.grab.last?.action == .resize)
        #expect(again.swallow)
    }

    @Test("an off action, or an off consumer, begins nothing")
    func offBeginsNothing() {
        var settings = ModifierDragSettings.defaults
        settings.move.chord = []
        var r = router(settings)
        #expect(r.route(sample(.leftDown, Self.moveChord), now: 1) == .pass)
        var off = PointerTapRouter()
        #expect(off.route(sample(.leftDown, Self.moveChord), now: 1) == .pass)
    }

    @Test("a hover grab begins on a move, passes it, ends on a key")
    func hoverGrab() {
        var settings = ModifierDragSettings.defaults
        settings.move.start = .hover
        var r = router(settings)
        // The press is no longer the move's to take.
        #expect(r.route(sample(.leftDown, Self.moveChord), now: 0) == .pass)
        let begin = r.route(sample(.mouseMoved, Self.moveChord), now: 1)
        #expect(!begin.swallow)
        #expect(begin.grab.map(\.phase) == [.began])
        #expect(begin.grab.first?.start == .hover)
        let move = r.route(sample(.mouseMoved, Self.moveChord, x: 20), now: 2)
        #expect(!move.swallow)
        #expect(move.grab.map(\.phase) == [.moved])
        let release = r.route(sample(.flagsChanged, [.control]), now: 3)
        #expect(!release.swallow)
        #expect(release.grab.map(\.phase) == [.ended])
        #expect(r.owner == nil)
    }

    @Test("a hover grab ends on a click, which stays the app's")
    func hoverEndsOnClick() {
        var settings = ModifierDragSettings.defaults
        settings.move.start = .hover
        var r = router(settings)
        _ = r.route(sample(.mouseMoved, Self.moveChord), now: 1)
        let click = r.route(sample(.leftDown, Self.moveChord), now: 2)
        #expect(!click.swallow)
        #expect(click.grab.map(\.phase) == [.ended])
    }

    @Test("a re-seed ends the grab in flight, and is quiet otherwise")
    func reseedEnds() {
        var r = router()
        #expect(r.reseed(now: 0, at: .zero) == .pass)
        _ = r.route(sample(.leftDown, Self.moveChord), now: 1)
        let reseeded = r.reseed(now: 2, at: .zero)
        #expect(reseeded.grab.map(\.phase) == [.ended])
        #expect(r.owner == nil)
    }

    @Test("a snapshot that turns the consumer off ends the grab")
    func snapshotOffEnds() {
        var r = router()
        _ = r.route(sample(.leftDown, Self.moveChord), now: 1)
        r.snapshot = .off
        let routed = r.route(sample(.leftDragged, []), now: 2)
        #expect(!routed.swallow)
        #expect(routed.grab.map(\.phase) == [.ended])
    }
}
