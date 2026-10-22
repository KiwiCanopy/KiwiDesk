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

    /// One show of the base row changed in one field.
    @MainActor private struct Variant {
        let field: String
        var items: [AppBarOverlay.Item]
        var active: Int? = 0
        var strip = AppBarTitleSlotTests.strip
        var style: AppBarLook?
        var capAxis: CGFloat? = nil
        var space: SpaceID? = nil
    }

    private func base() -> [AppBarOverlay.Item] {
        [item(1, "a"), item(2, "b")]
    }

    private func with(
        _ field: String,
        _ change: (inout AppBarOverlay.Item) -> Void
    ) -> Variant {
        var items = base()
        change(&items[0])
        return Variant(field: field, items: items)
    }

    private func edited(
        _ old: AppBarOverlay.Item,
        text: String? = nil,
        name: String? = nil,
        icon: NSImage?? = nil,
        glyph: String?? = nil,
        count: Int? = nil,
        members: [WindowID]? = nil,
        titleCut: Bool? = nil,
        floating: Bool? = nil,
        visibility: BarVisibility? = nil
    ) -> AppBarOverlay.Item {
        AppBarOverlay.Item(
            id: old.id,
            name: name ?? old.name,
            text: text ?? old.text,
            icon: icon ?? old.icon,
            glyph: glyph ?? old.glyph,
            count: count ?? old.count,
            members: members ?? old.members,
            titleCut: titleCut ?? old.titleCut,
            floating: floating ?? old.floating,
            visibility: visibility ?? old.visibility
        )
    }

    /// Every field the census marks compared, changed alone, runs
    /// the frame pass; every content field, changed alone, does not.
    @Test("Each compared field runs the frame pass, content does not")
    func comparedFieldsRender() {
        var style = AppBarLook()
        style.fontSize = 18
        let compared: [Variant] = [
            Variant(field: "activeIndex", items: base(), active: 1),
            Variant(
                field: "strip",
                items: base(),
                strip: CGRect(x: 0, y: 0, width: 700, height: 30)
            ),
            Variant(field: "style", items: base(), style: style),
            Variant(field: "capAxis", items: base(), capAxis: 400),
            Variant(field: "space", items: base(), space: SpaceID("2")),
            // Members held, so the id alone differs.
            Variant(
                field: "id",
                items: base().map {
                    AppBarOverlay.Item(
                        id: WindowID($0.id.raw + 10),
                        name: $0.name,
                        text: $0.text,
                        icon: nil,
                        members: $0.members
                    )
                }
            ),
            with("count") { $0 = edited($0, count: 2) },
            with("members") {
                $0 = edited($0, members: [WindowID(1), WindowID(9)])
            },
            with("floating") { $0 = edited($0, floating: true) },
            with("visibility") { $0 = edited($0, visibility: .hidden) },
            with("icon") {
                let icon = NSImage(size: NSSize(width: 8, height: 8))
                $0 = edited($0, icon: icon)
            },
            with("glyph") { $0 = edited($0, glyph: ":safari:") },
            with("text") { $0 = edited($0, text: "") },
            Variant(field: "items", items: base() + [item(3, "c")]),
        ]
        let content: [Variant] = [
            with("text") { $0 = edited($0, text: "CLAUDE AGE…") },
            with("name") { $0 = edited($0, name: "Terminal") },
            with("titleCut") { $0 = edited($0, titleCut: true) },
        ]
        let fields = Set(self.state.keys).union(self.fields.keys)
        for variant in compared + content {
            #expect(fields.contains(variant.field), "\(variant.field)")
        }
        for (variants, renders) in [(compared, 1), (content, 0)] {
            for variant in variants {
                let overlay = AppBarOverlay()
                show(overlay, base())
                let draws = overlay.draws
                overlay.show(
                    items: variant.items,
                    activeIndex: variant.active,
                    strip: variant.strip,
                    style: variant.style ?? AppBarLook(),
                    capAxis: variant.capAxis,
                    space: variant.space
                )
                #expect(
                    overlay.draws == draws + renders,
                    "\(variant.field)"
                )
            }
        }
    }

    /// The slot is measured as the labels draw — a centred field,
    /// whose cell runs wider than a natural one's — read here from
    /// an independent centred label rather than the slot itself.
    @Test("The slot measures a centred label's padding")
    func slotMeasuresACentredLabel() {
        let font = AppBarLook().shelf.textFont(ofSize: 13)
        let label = NSTextField(labelWithString: "…")
        label.font = font
        label.alignment = .center
        let ellipsis = ceil(label.cell?.cellSize.width ?? 0)
        // A cap of nothing leaves the ellipsis and the padding.
        #expect(BarTitleSlot.length(cap: 0, font: font) >= ellipsis)
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
