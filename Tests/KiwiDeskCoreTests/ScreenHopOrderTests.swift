import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Which screen lies which way (#2493, #2512): a pure reading of
/// AX frames. A plus of five screens — C in the middle, N, S, E and
/// W around it — is the ruling's own example.
@Suite("Screen hop order (#2493)")
struct ScreenHopOrderTests {
    private static let c = DisplayID(1)
    private static let n = DisplayID(2)
    private static let s = DisplayID(3)
    private static let e = DisplayID(4)
    private static let w = DisplayID(5)

    private static let plus: [ScreenHop.Screen] = [
        (c, CGRect(x: 0, y: 0, width: 100, height: 100)),
        (n, CGRect(x: 0, y: -100, width: 100, height: 100)),
        (s, CGRect(x: 0, y: 100, width: 100, height: 100)),
        (e, CGRect(x: 100, y: 0, width: 100, height: 100)),
        (w, CGRect(x: -100, y: 0, width: 100, height: 100)),
    ]

    private func frame(_ id: DisplayID) -> CGRect {
        Self.plus.first { $0.id == id }!.frame
    }

    private func order(
        _ from: DisplayID,
        _ direction: Direction
    ) -> [DisplayID] {
        ScreenHop.hopOrder(
            from: from,
            in: direction,
            band: frame(from).insetBy(dx: 10, dy: 10),
            among: Self.plus
        )
    }

    @Test("the nearest screen that way comes first")
    func nearestFirst() {
        #expect(order(Self.w, .right) == [Self.c, Self.e])
        #expect(order(Self.c, .right) == [Self.e, Self.w])
    }

    @Test("past the last screen the far side wraps, farthest first")
    func wrapsFarthestFirst() {
        // → from east lands on west; ↑ from north on south.
        #expect(order(Self.e, .right) == [Self.w, Self.c])
        #expect(order(Self.n, .up) == [Self.s, Self.c])
    }

    @Test("a diagonal screen is no neighbour")
    func diagonalIsNone() {
        // → from north: nothing shares north's band, so the wrap
        // is north's own.
        #expect(order(Self.n, .right).isEmpty)
        #expect(
            ScreenHop.ahead(
                of: frame(Self.n),
                in: .right,
                band: frame(Self.n),
                among: Self.plus
            ).isEmpty
        )
    }

    @Test("the entry seed sits just outside the entering edge")
    func entrySeed() {
        let bounds = CGRect(x: 100, y: 0, width: 100, height: 100)
        let band = CGRect(x: 0, y: 20, width: 50, height: 30)
        let right = ScreenHop.entrySeed(
            into: bounds,
            entering: .right,
            band: band
        )
        #expect(right.maxX < bounds.minX)
        #expect(right.minY == band.minY && right.height == band.height)
        let up = ScreenHop.entrySeed(
            into: bounds,
            entering: .up,
            band: band
        )
        #expect(up.minY > bounds.maxY)
        #expect(up.minX == band.minX && up.width == band.width)
    }
}
