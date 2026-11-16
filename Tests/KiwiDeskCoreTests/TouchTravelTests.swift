import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The two-finger travel a long swipe counts (#1873 ▸ Ruling
/// 2026-11-16): the mean move of the contacts two frames share,
/// only while exactly two are down, in the pad's mm.
@Suite("Touch travel")
struct TouchTravelTests {
    private let pad = CGSize(width: 100, height: 50)

    private func two(_ x: Float, _ y: Float) -> [TouchContact] {
        [
            TouchContact(id: 1, x: x, y: y),
            TouchContact(id: 2, x: x + 0.1, y: y),
        ]
    }

    @Test("two fingers moving add their mean move in mm")
    func twoFingersAdd() {
        var travel = TouchTravel()
        travel.feed(device: 1, contacts: two(0.2, 0.5), size: pad)
        travel.feed(device: 1, contacts: two(0.3, 0.6), size: pad)
        #expect(abs(travel.sum.dx - 10) < 0.001)
        #expect(abs(travel.sum.dy - 5) < 0.001)
    }

    /// A finger landing or lifting moves the centroid but adds
    /// nothing, so a count change never jumps the sum.
    @Test("a changed contact set adds nothing")
    func fingerChangeAddsNothing() {
        var travel = TouchTravel()
        travel.feed(device: 1, contacts: two(0.2, 0.5), size: pad)
        travel.feed(
            device: 1,
            contacts: two(0.2, 0.5) + [TouchContact(id: 3, x: 0.9, y: 0.9)],
            size: pad
        )
        travel.feed(
            device: 1,
            contacts: [
                TouchContact(id: 1, x: 0.2, y: 0.5),
                TouchContact(id: 4, x: 0.8, y: 0.1),
            ],
            size: pad
        )
        #expect(travel.sum == .zero)
    }

    /// A swap of one finger for another between two frames is no
    /// pair: the finger kept moving adds nothing either.
    @Test("a swapped finger adds nothing")
    func swapAddsNothing() {
        var travel = TouchTravel()
        travel.feed(
            device: 1,
            contacts: [
                TouchContact(id: 1, x: 0.2, y: 0.5),
                TouchContact(id: 2, x: 0.3, y: 0.5),
            ],
            size: pad
        )
        travel.feed(
            device: 1,
            contacts: [
                TouchContact(id: 1, x: 0.6, y: 0.5),
                TouchContact(id: 4, x: 0.3, y: 0.5),
            ],
            size: pad
        )
        #expect(travel.sum == .zero)
    }

    @Test("one finger adds nothing")
    func oneFingerAddsNothing() {
        var travel = TouchTravel()
        let one = [TouchContact(id: 1, x: 0.2, y: 0.5)]
        travel.feed(device: 1, contacts: one, size: pad)
        travel.feed(
            device: 1,
            contacts: [TouchContact(id: 1, x: 0.6, y: 0.5)],
            size: pad
        )
        #expect(travel.sum == .zero)
    }

    /// Each pad is its own: an idle second pad's frames break no
    /// pair on the first.
    @Test("devices pair their own frames")
    func devicesApart() {
        var travel = TouchTravel()
        travel.feed(device: 1, contacts: two(0.2, 0.5), size: pad)
        travel.feed(device: 2, contacts: [], size: pad)
        travel.feed(device: 1, contacts: two(0.3, 0.5), size: pad)
        #expect(abs(travel.sum.dx - 10) < 0.001)
    }

    @Test("a pad with no size adds nothing")
    func sizelessPadAddsNothing() {
        var travel = TouchTravel()
        travel.feed(device: 1, contacts: two(0.2, 0.5), size: nil)
        travel.feed(device: 1, contacts: two(0.3, 0.5), size: nil)
        #expect(travel.sum == .zero)
    }

    /// The reading follows the pad carrying two fingers: a sized pad
    /// reads, an unsized one answers nil, so its swipe counts points.
    @Test("the reading follows the pad carrying the fingers")
    func readingFollowsThePad() {
        var travel = TouchTravel(generation: 1)
        #expect(travel.reading == nil)
        travel.feed(device: 1, contacts: two(0.2, 0.5), size: pad)
        let sized = travel.reading
        #expect(sized != nil)
        travel.feed(device: 2, contacts: two(0.2, 0.5), size: nil)
        #expect(travel.reading == nil)
        travel.feed(device: 1, contacts: two(0.3, 0.5), size: pad)
        #expect(travel.reading?.source == sized?.source)
    }

    /// Two readers never share a source, so a rebuilt one's sum is
    /// never differenced against the last.
    @Test("each reader is its own source")
    func generationsDiffer() {
        var first = TouchTravel(generation: 1)
        var second = TouchTravel(generation: 2)
        first.feed(device: 1, contacts: two(0.2, 0.5), size: pad)
        second.feed(device: 1, contacts: two(0.2, 0.5), size: pad)
        #expect(first.reading?.source != second.reading?.source)
    }
}
