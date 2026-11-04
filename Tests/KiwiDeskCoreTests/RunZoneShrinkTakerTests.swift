import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The answer the mouse drop and `RunZone.press` share (#2970), on
/// the arms a drag cannot reach: a hidden window has no edge to drag
/// and a piled zone draws no run. Pure, over one horizontal zone of
/// four windows with 300-pt floors.
@Suite("Run zone shrink taker (#2970)")
struct RunZoneShrinkTakerTests {
    private let ids = (1...4).map { WindowID(UInt32($0)) }

    private func zone(width: CGFloat) -> RunZone {
        RunZone(
            members: ids,
            region: CGRect(x: 0, y: 0, width: width, height: 600),
            vertical: false
        )
    }

    private func context(width: CGFloat) -> LayoutContext {
        LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: width, height: 600),
            focused: ids[0],
            minWindowSize: 300
        )
    }

    @Test("A hidden window has no taker, a shown one beside a mate has")
    func hiddenAnswersNil() throws {
        let zone = zone(width: 1000)
        let context = context(width: 1000)
        let run = try #require(zone.run(in: context))
        #expect(run.hides)
        #expect(run.visible.contains(0))
        #expect(!run.visible.contains(3))
        #expect(zone.shrinkTaker(of: ids[0], in: context) == .shownMate)
        #expect(zone.shrinkTaker(of: ids[3], in: context) == nil)
    }

    @Test("A zone that piles has no taker")
    func pileAnswersNil() {
        let zone = zone(width: 200)
        let context = context(width: 200)
        #expect(zone.piles(in: context))
        #expect(zone.shrinkTaker(of: ids[0], in: context) == nil)
    }

    @Test("A window no member of the zone has no taker")
    func strangerAnswersNil() {
        let zone = zone(width: 1000)
        #expect(
            zone.shrinkTaker(
                of: WindowID(UInt32(99)),
                in: context(width: 1000)
            ) == nil
        )
    }
}
