import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The centred strip on the chip itself (#1528 items 17, 21): a
/// leading `+n` disc with its own target ahead of the glyphs, a
/// strip that moved under the same Space walks — the glyphs it
/// carries off kept to fade under their disc — and a chip reports
/// the pointer resting on it with the strip it drew.
@Suite("Space Bar strip on the chip")
@MainActor
struct SpaceBarStripViewTests {
    private static let depth: CGFloat = 32

    private func app(_ id: UInt32) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: "App\(id)",
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            focused: false,
            count: 1,
            windows: [WindowID(id)]
        )
    }

    private func configure(
        _ view: SpaceBarItemView,
        drawn: ClosedRange<UInt32>,
        of count: UInt32 = 9
    ) {
        var style = SpaceBarLook()
        style.glyphGap = 0
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: drawn.map(app),
            active: true,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            ),
            overflow: Int(count - drawn.upperBound),
            overflowWindows: ((drawn.upperBound + 1)..<(count + 1))
                .map(WindowID.init),
            overflowBefore: (1..<drawn.lowerBound).map(WindowID.init),
            strip: Int(drawn.lowerBound - 1)..<Int(drawn.upperBound)
        )
        view.layout()
    }

    private func makeView() -> SpaceBarItemView {
        let length = SpaceBarItemView.autoLength(
            appCount: 5,
            discs: 2,
            contentDepth: Self.depth,
            glyphGap: 0
        )
        return SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: length, height: Self.depth)
        )
    }

    @Test("the leading disc sits before the glyphs with its own target")
    func leadingDiscLeads() throws {
        let view = makeView()
        configure(view, drawn: 3...7)
        let leading = try #require(view.leadingTarget)
        let trailing = try #require(view.overflowTarget)
        #expect(leading.members == [WindowID(1), WindowID(2)])
        #expect(trailing.members == [WindowID(8), WindowID(9)])
        let first = try #require(view.appViews.first)
        #expect(leading.frame.maxX <= first.frame.minX)
        #expect(!view.leadingBadge.isHidden)
        #expect(view.leadingBadge.stringValue == "+2")
        #expect(
            leading.accessibilityLabel() == "Earlier windows not shown: 2"
        )
    }

    /// A step forward carries the leading glyph off: it is kept
    /// for its fade while the new glyphs draw, and the walk is
    /// consumed by the layout that plays it.
    @Test("a moved strip walks and keeps the glyph it carries off")
    func movedStripWalks() {
        let view = makeView()
        configure(view, drawn: 3...7)
        let carried = view.appViews[0]
        configure(view, drawn: 4...8)
        #expect(view.leavingViews.count == 1)
        #expect(view.leavingViews.first === carried)
        #expect(carried.superview === view)
        #expect(view.pendingWalk == nil)
        #expect(view.appViews.count == 5)
    }

    @Test("an unmoved strip walks nothing")
    func unmovedStripStays() {
        let view = makeView()
        configure(view, drawn: 3...7)
        configure(view, drawn: 3...7)
        #expect(view.leavingViews.isEmpty)
    }

    @Test("the chip reports the pointer with the strip it drew")
    func reportsThePointer() {
        let view = makeView()
        configure(view, drawn: 3...7)
        var reports: [(SpaceID, Range<Int>?, Bool)] = []
        view.onPointerInside = { reports.append(($0, $1, $2)) }
        view.setPointerInside(true)
        view.setPointerInside(true)
        view.setPointerInside(false)
        #expect(reports.map(\.2) == [true, false])
        #expect(reports.first?.1 == 2..<7)
    }
}
