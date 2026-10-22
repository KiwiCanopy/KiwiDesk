import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Bar title change moves no frame (#2545, owner ruling):
/// every title draws in the one fixed `titleSlot`, so a show whose
/// titles alone changed redraws its items' text without the frame
/// pass — the front-app segment's rule (#2086). Every stored field
/// of a show is COMPARED by `keepsGeometry` or CONTENT, redrawn in
/// place by `configure`; a new field reds the census until it is
/// classified.
@Suite("App Bar fixed title slot", .serialized)
@MainActor
struct AppBarTitleSlotTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    private static let strip = CGRect(x: 0, y: 0, width: 900, height: 30)

    /// `RenderState`'s fields → how the content path treats each.
    private let state: [String: String] = [
        "items": "per item, below",
        "activeIndex": "compared",
        "strip": "compared",
        "style": "compared",
        "capAxis": "compared",
        "space": "compared",
    ]

    /// `Item`'s fields → how the content path treats each.
    private let fields: [String: String] = [
        "id": "compared (samePlace)",
        "count": "compared (samePlace)",
        "members": "compared (samePlace)",
        "floating": "compared (samePlace)",
        "visibility": "compared (samePlace)",
        "icon": "compared (samePlace)",
        "glyph": "compared (samePlace)",
        "text": "content; its presence compared",
        "name": "content",
        "titleCut": "content",
    ]

    private static func labels(_ value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }

    private func item(_ id: UInt32, _ text: String) -> AppBarOverlay.Item {
        AppBarOverlay.Item(
            id: WindowID(id),
            name: "Ghostty",
            text: text,
            icon: nil
        )
    }

    private func show(
        _ overlay: AppBarOverlay,
        _ items: [AppBarOverlay.Item],
        active: Int? = 0
    ) {
        overlay.show(
            items: items,
            activeIndex: active,
            strip: Self.strip,
            style: AppBarLook()
        )
    }

    @Test("A renamed window redraws its text and moves no frame")
    func renameRedrawsContentAlone() {
        let overlay = AppBarOverlay()
        let cap = AppBarLook().resolvedTitleCap
        let lower = AppBarStyle.cappedTitle("space switch stalls", to: cap)
        let upper = AppBarStyle.cappedTitle("CLAUDE AGENT LANE", to: cap)
        show(overlay, [item(1, lower), item(2, "zsh")])
        let draws = overlay.draws
        let frames = overlay.itemViews.map(\.frame)
        let plate = overlay.plateFrame
        show(overlay, [item(1, upper), item(2, "zsh")])
        #expect(overlay.draws == draws)
        #expect(overlay.itemViews.map(\.frame) == frames)
        #expect(overlay.plateFrame == plate)
        overlay.itemViews[0].layout()
        #expect(overlay.itemViews[0].label.stringValue == upper)
        #expect(overlay.itemViews.map(\.frame) == frames)
    }

    @Test("Every stored field of a show is classified")
    func everyFieldIsClassified() {
        let one = item(1, "a")
        let state = AppBarOverlay.RenderState(
            items: [one],
            activeIndex: 0,
            strip: Self.strip,
            style: AppBarLook(),
            capAxis: nil,
            space: nil
        )
        #expect(Self.labels(state) == Set(self.state.keys))
        #expect(Self.labels(one) == Set(fields.keys))
    }

    /// A content redraw lands every frame where a fresh overlay's
    /// full render of the same input puts it, the labels included.
    @Test("A content redraw draws a full render's frames")
    func redrawMatchesAFullRender() {
        let next = [item(1, "CLAUDE AGE…"), item(2, "zsh")]
        let redrawn = AppBarOverlay()
        show(redrawn, [item(1, "space swit…"), item(2, "Mail")])
        show(redrawn, next)
        let fresh = AppBarOverlay()
        show(fresh, next)
        let frames = { (o: AppBarOverlay) -> [CGRect] in
            o.itemViews.forEach { $0.layout() }
            return [o.contentFrame, o.plateFrame, o.itemRun.frame]
                + o.itemViews.map(\.frame)
                + o.itemViews.map(\.label.frame)
                + o.itemViews.map(\.glyphLabel.frame)
        }
        #expect(redrawn.draws == 1)
        #expect(frames(redrawn) == frames(fresh))
        #expect(
            redrawn.itemViews.map(\.label.stringValue)
                == fresh.itemViews.map(\.label.stringValue)
        )
    }

    @Test("A focus or membership change still runs the frame pass")
    func placeChangeRenders() {
        let overlay = AppBarOverlay()
        show(overlay, [item(1, "a"), item(2, "b")])
        let draws = overlay.draws
        show(overlay, [item(1, "a"), item(2, "b")], active: 1)
        #expect(overlay.draws == draws + 1)
        show(overlay, [item(1, "a"), item(2, "b"), item(3, "c")], active: 1)
        #expect(overlay.draws == draws + 2)
        // A title appearing where none was places the icon anew.
        show(overlay, [item(1, "a"), item(2, "b"), item(3, "")], active: 1)
        #expect(overlay.draws == draws + 3)
    }

    @Test("The shelf's need holds across title changes")
    func naturalLengthIgnoresTitles() {
        let look = AppBarLook()
        let need = { (texts: [String]) in
            AppBarOverlay.naturalLength(
                items: texts.enumerated().map {
                    item(UInt32($0.offset + 1), $0.element)
                },
                style: look,
                thickness: Self.strip.height,
                capAxis: Self.strip.width
            )
        }
        #expect(need(["space swit…", "zsh"]) == need(["CLAUDE AGE…", "x"]))
    }
}
