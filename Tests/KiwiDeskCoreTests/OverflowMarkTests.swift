import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let ids = (1...6).map { WindowID(UInt32($0)) }
private let bounds = CGRect(x: 0, y: 30, width: 1440, height: 800)

/// A cover of one zone of six members showing `visible`.
private func cover(
    visible: Range<Int>,
    vertical: Bool = true
) -> RunCover {
    RunCover(
        space: "1",
        runs: [
            RunCover.Run(
                zone: RunZone(
                    members: ids,
                    region: bounds.insetBy(dx: 10, dy: 10),
                    vertical: vertical
                ),
                run: ZoneRun(visible: visible, count: ids.count),
                extra: 0
            )
        ],
        bounds: bounds
    )
}

/// The overflow mark's derivation and geometry (#2235 ▸ Ruling —
/// the overflow mark): one per hiding end, nearest window first,
/// a pill along a top or bottom edge and a circle on a side, its
/// outer edge flush with the layout bounds.
@Suite("Overflow mark")
struct OverflowMarkTests {
    @Test("Each hiding end gets a mark counting only that end")
    func oneMarkPerHidingEnd() throws {
        let marks = OverflowMark.marks(of: cover(visible: 2..<4))
        #expect(marks.count == 2)
        let top = try #require(marks.first { $0.end == .top })
        let bottom = try #require(marks.first { $0.end == .bottom })
        #expect(top.anchor == ids[2])
        #expect(bottom.anchor == ids[3])
        // Nearest the edge first: the order one focus step at a
        // time brings them in.
        #expect(top.windows == [ids[1], ids[0]])
        #expect(bottom.windows == [ids[4], ids[5]])
        #expect(top.bounds == bounds)
    }

    @Test("A zone that hides nothing at one end has no mark there")
    func noMarkWithoutHidden() {
        let marks = OverflowMark.marks(of: cover(visible: 0..<3))
        #expect(marks.map(\.end) == [.bottom])
        #expect(OverflowMark.marks(of: RunCover(space: "1", runs: [])).isEmpty)
    }

    @Test("A sideways zone's marks sit on its left and right ends")
    func sidewaysEnds() {
        let marks = OverflowMark.marks(
            of: cover(visible: 1..<5, vertical: false)
        )
        #expect(Set(marks.map(\.end)) == [.left, .right])
    }

    @Test("A pill along the edge, a circle sized to the text on a side")
    func shapes() {
        let pill = OverflowMark.size(end: .top, textWidth: 12)
        #expect(pill == CGSize(width: 26, height: OverflowMark.depth))
        let narrow = OverflowMark.size(end: .bottom, textWidth: 1)
        #expect(narrow.width == OverflowMark.depth)
        let circle = OverflowMark.size(end: .left, textWidth: 12)
        #expect(circle == CGSize(width: 18, height: 18))
        let wide = OverflowMark.size(end: .right, textWidth: 20)
        #expect(wide.width == wide.height && wide.width == 24)
    }

    @Test("The outer edge sits on the bounds, reaching depth less gap")
    func flushWithBounds() {
        let size = CGSize(width: 26, height: 18)
        // A 10 pt outer gap above the window.
        let anchor = CGRect(x: 100, y: 40, width: 400, height: 300)
        let top = OverflowMark.frame(
            end: .top,
            size: size,
            anchor: anchor,
            bounds: bounds
        )
        #expect(top.minY == bounds.minY)
        #expect(top.maxY - anchor.minY == 8)
        #expect(top.midX == anchor.midX)
        let below = CGRect(x: 100, y: 520, width: 400, height: 300)
        let bottom = OverflowMark.frame(
            end: .bottom,
            size: size,
            anchor: below,
            bounds: bounds
        )
        #expect(bottom.maxY == bounds.maxY)
    }

    @Test("A gap deeper than the mark keeps it on the window's edge")
    func deepGapTouchesTheWindow() {
        let size = CGSize(width: 18, height: 18)
        let anchor = CGRect(x: 60, y: 100, width: 400, height: 300)
        let left = OverflowMark.frame(
            end: .left,
            size: size,
            anchor: anchor,
            bounds: bounds
        )
        #expect(left.maxX == anchor.minX)
        #expect(left.midY == anchor.midY)
    }

    @Test("With no outer gap the mark sits wholly on the window")
    func noGapSitsOnTheWindow() {
        let size = CGSize(width: 26, height: 18)
        let anchor = CGRect(x: 0, y: 30, width: 400, height: 300)
        let top = OverflowMark.frame(
            end: .top,
            size: size,
            anchor: anchor,
            bounds: bounds
        )
        #expect(top.minY == anchor.minY)
        // Along the edge it is kept inside the bounds.
        #expect(top.minX >= bounds.minX)
    }
}
