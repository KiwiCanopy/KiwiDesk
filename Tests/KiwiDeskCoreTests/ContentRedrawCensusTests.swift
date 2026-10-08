import AppKit
import Testing

@testable import KiwiDeskCore

/// The content redraw (#2086) must draw what a full render would:
/// every stored field of a Space Bar show is either COMPARED by
/// `keepsGeometry` — a change sends it through the frame pass — or
/// CONTENT, redrawn in place by `configure` / `renderFrontSegment`,
/// whose lengths the comparison measures. A new field reds the
/// census until it is classified, and the differential clause holds
/// a content redraw to a fresh full render's frames.
@Suite("Content redraw census (#2086)", .serialized)
@MainActor
struct ContentRedrawCensusTests {
    init() { LiquidGlassGate.override = { false } }

    /// `Shown`'s fields → how the content path treats each.
    private let shown: [String: String] = [
        "items": "per item, below",
        "frontApp": "content; its extent and presence compared",
        "strip": "compared",
        "style": "compared",
        "stateMarkColors": "compared",
    ]

    /// `Item`'s fields → how the content path treats each.
    private let item: [String: String] = [
        "identity": "compared (samePlace)",
        "spaceGlyph": "compared (samePlace)",
        "active": "compared (samePlace)",
        "marker": "compared (samePlace)",
        "collapse": "compared (samePlace)",
        "apps": "content; the item's length compared",
        "before": "content; the item's length compared",
        "after": "content; the item's length compared",
        "drawn": "content; the item's length compared",
    ]

    private static let strip = CGRect(x: 0, y: 0, width: 900, height: 28)

    private static func app(
        _ name: String,
        focused: Bool,
        title: String? = nil
    ) -> SpaceBarItemView.App {
        var app = SpaceBarItemView.App(
            name: name,
            icon: nil,
            glyph: nil,
            focused: focused,
            count: 1
        )
        app.title = title
        return app
    }

    private static func items(focus web: Bool) -> [SpaceBarOverlay.Item] {
        [
            SpaceBarOverlay.Item(
                space: SpaceID("1"),
                spaceGlyph: .text("1", tinted: true),
                apps: [
                    app("Notes", focused: !web),
                    app("Web", focused: web),
                ],
                active: true,
                after: .none
            )
        ]
    }

    private static var look: SpaceBarLook {
        var look = SpaceBarLook()
        look.showFrontApp = true
        look.liquidGlass = false
        look.backgroundStyle = .plain
        look.alignment = .center
        return look
    }

    private func show(_ overlay: SpaceBarOverlay, web: Bool) {
        overlay.show(
            items: Self.items(focus: web),
            frontApp: Self.app(
                web ? "Web" : "Notes",
                focused: true,
                title: web ? "A long page title here" : "Memo"
            ),
            strip: Self.strip,
            style: Self.look,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
    }

    private static func labels(_ value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }

    @Test("Every stored field of a show is classified")
    func everyFieldIsClassified() {
        let item = Self.items(focus: false)[0]
        let shown = SpaceBarOverlay.Shown(
            items: [item],
            frontApp: nil,
            strip: Self.strip,
            style: Self.look,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        #expect(Self.labels(shown) == Set(self.shown.keys))
        #expect(Self.labels(item) == Set(self.item.keys))
    }

    /// A content redraw lands every frame where a fresh overlay's
    /// full render of the same input puts it.
    @Test("A content redraw draws a full render's frames")
    func redrawMatchesAFullRender() {
        let redrawn = SpaceBarOverlay()
        show(redrawn, web: false)
        show(redrawn, web: true)
        let fresh = SpaceBarOverlay()
        show(fresh, web: true)
        let frames = { (o: SpaceBarOverlay) in
            [
                o.contentFrame, o.plateFrame, o.itemRun.frame,
                o.frontIcon.frame, o.frontName.frame,
            ] + o.itemViews.map(\.frame)
        }
        #expect(frames(redrawn) == frames(fresh))
        #expect(redrawn.frontName.stringValue == fresh.frontName.stringValue)
        #expect(
            redrawn.itemViews.map(\.apps) == fresh.itemViews.map(\.apps)
        )
    }
}
