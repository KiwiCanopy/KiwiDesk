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
        _ indicator: AppBarStyle.ActiveIndicator
    ) -> SpaceBarItemView {
        var look = SpaceBarLook()
        look.highlightWidth = Self.width
        look.activeIndicator = indicator
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 80, height: 40)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [],
            active: true,
            horizontal: true,
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
        _ indicator: AppBarStyle.ActiveIndicator
    ) -> AppBarItemView {
        var look = AppBarLook()
        look.highlightWidth = Self.width
        look.activeIndicator = indicator
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 40)
        )
        view.configure(
            id: WindowID(1),
            text: "Zed",
            icon: nil,
            glyph: nil,
            count: 1,
            active: true,
            horizontal: true,
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

    @Test("The Space Bar's edge mark takes the derived thickness")
    func spaceEdgeMark() {
        let view = spaceItem(.edgeMark)
        #expect(
            view.accent.frame.height
                == Self.width * KiwiShelf.edgeMarkRatio
        )
    }

    @Test("The App Bar's outline strokes at the width")
    func appOutline() {
        let view = appItem(.outline)
        #expect(view.accent.layer?.borderWidth == Self.width)
    }

    @Test("The App Bar's edge mark takes the derived thickness")
    func appEdgeMark() {
        let view = appItem(.edgeMark)
        #expect(
            view.accent.frame.height
                == Self.width * KiwiShelf.edgeMarkRatio
        )
    }
}
