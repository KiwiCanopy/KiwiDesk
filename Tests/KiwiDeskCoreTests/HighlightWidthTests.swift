import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.highlight_width` (#1680): one weight for both bars'
/// active indicator — the outline's stroke, the edge mark at
/// `KiwiShelf.edgeMarkRatio` of it — clamped at decode and set.
@Suite("KiwiShelf highlight width")
struct HighlightWidthTests {
    /// The default is the look that shipped before the setting:
    /// a 2 pt ring and a 3 pt edge mark.
    @Test("The default draws the pre-setting indicator")
    func defaultIsTodaysLook() {
        let shelf = KiwiShelf()
        #expect(shelf.highlightWidth == 2)
        #expect(shelf.edgeMarkThickness == 3)
    }

    @Test("The edge mark follows the width")
    func edgeMarkScales() {
        var shelf = KiwiShelf()
        shelf.highlightWidth = 4
        #expect(shelf.edgeMarkThickness == 4 * KiwiShelf.edgeMarkRatio)
    }

    /// A writer that skips the clamp still draws inside the range:
    /// drawings read the resolved width, never the stored one.
    @Test("A drawing reads the width clamped, whoever wrote it")
    func readersClamp() {
        var shelf = KiwiShelf()
        shelf.highlightWidth = 20
        #expect(shelf.resolvedHighlightWidth == 6)
        #expect(shelf.edgeMarkThickness == 6 * KiwiShelf.edgeMarkRatio)
    }

    @Test(
        "Decode clamps to the range",
        arguments: [(0.2, 1.0), (40.0, 6.0), (3.5, 3.5)]
    )
    func decodeClamps(stored: Double, drawn: Double) throws {
        let json = #"{"highlight_width": \#(stored)}"#
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(json.utf8)
        )
        #expect(shelf.highlightWidth == CGFloat(drawn))
    }

    @Test(
        "The setter clamps to the range",
        arguments: [(-3.0, 1.0), (0.5, 1.0), (9.0, 6.0), (2.5, 2.5)]
    )
    func setterClamps(value: Double, stored: Double) throws {
        let setting = try KiwiShelfCommandSetting.parse(
            field: "highlight_width",
            args: [.number(value)]
        ).get()
        var shelf = KiwiShelf()
        setting.apply(to: &shelf)
        #expect(shelf.highlightWidth == CGFloat(stored))
    }
}

/// The drawing reads the width: both bars' outline stroke and
/// edge mark, built through their real item views.
@Suite("Highlight width reaches both bars")
@MainActor
struct HighlightWidthDrawingTests {
    private static let width: CGFloat = 4

    private func spaceItem(
        _ indicator: AppBarStyle.ActiveIndicator,
        edge: AppBarEdge = .top
    ) -> SpaceBarItemView {
        var look = SpaceBarLook()
        look.highlightWidth = Self.width
        look.activeIndicator = indicator
        look.edge = edge
        let view = SpaceBarItemView(
            frame: edge.isHorizontal
                ? CGRect(x: 0, y: 0, width: 80, height: 40)
                : CGRect(x: 0, y: 0, width: 40, height: 80)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [],
            active: true,
            horizontal: edge.isHorizontal,
            style: look,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        return view
    }

    private func appItem(
        _ indicator: AppBarStyle.ActiveIndicator,
        edge: AppBarEdge = .top
    ) -> AppBarItemView {
        var look = AppBarLook()
        look.highlightWidth = Self.width
        look.activeIndicator = indicator
        look.edge = edge
        let view = AppBarItemView(
            frame: edge.isHorizontal
                ? NSRect(x: 0, y: 0, width: 120, height: 40)
                : NSRect(x: 0, y: 0, width: 40, height: 120)
        )
        view.configure(
            id: WindowID(1),
            text: "Zed",
            icon: nil,
            glyph: nil,
            count: 1,
            active: true,
            horizontal: edge.isHorizontal,
            style: look
        )
        view.layout()
        return view
    }

    @Test("The Space Bar's outline strokes at the width")
    func spaceOutline() {
        let view = spaceItem(.outline)
        #expect(view.accent.layer?.borderWidth == Self.width)
    }

    /// The mark's cross extent: its height on a top or bottom
    /// shelf, its width on a side one.
    private func markDepth(_ frame: CGRect, _ edge: AppBarEdge) -> CGFloat {
        edge.isHorizontal ? frame.height : frame.width
    }

    @Test(
        "The Space Bar's edge mark takes the derived thickness",
        arguments: [AppBarEdge.top, .bottom, .left, .right]
    )
    func spaceEdgeMark(edge: AppBarEdge) {
        let view = spaceItem(.edgeMark, edge: edge)
        #expect(
            markDepth(view.accent.frame, edge)
                == Self.width * KiwiShelf.edgeMarkRatio
        )
    }

    @Test("The Space Bar's drop ring strokes at the width")
    func spaceDropRing() {
        let view = spaceItem(.outline)
        view.beginSpringSweep(duration: 0.1, delay: 0)
        #expect(view.springRing.lineWidth == Self.width)
    }

    @Test("The App Bar's outline strokes at the width")
    func appOutline() {
        let view = appItem(.outline)
        #expect(view.accent.layer?.borderWidth == Self.width)
    }

    @Test(
        "The App Bar's edge mark takes the derived thickness",
        arguments: [AppBarEdge.top, .bottom, .left, .right]
    )
    func appEdgeMark(edge: AppBarEdge) {
        let view = appItem(.edgeMark, edge: edge)
        #expect(
            markDepth(view.accent.frame, edge)
                == Self.width * KiwiShelf.edgeMarkRatio
        )
    }
}
