import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.glyph_gap` (#1689): room between a Space item's app
/// glyph cells and before its `+n` badge, clamped at decode and
/// set, and read by the item's layout, its measured length and
/// the shelf's plan alike.
@Suite("Space Bar glyph gap")
struct GlyphGapTests {
    @Test("The default abuts the cells, as before the setting")
    func defaultAbuts() {
        #expect(SpaceBarStyle().resolvedGlyphGap == 0)
    }

    @Test(
        "Decode clamps to the range",
        arguments: [(-4.0, 0.0), (40.0, 24.0), (5.0, 5.0)]
    )
    func decodeClamps(stored: Double, drawn: Double) throws {
        let json = #"{"glyph_gap": \#(stored)}"#
        let style = try JSONDecoder().decode(
            SpaceBarStyle.self,
            from: Data(json.utf8)
        )
        #expect(style.glyphGap == CGFloat(drawn))
    }

    @Test(
        "The setter clamps to the range",
        arguments: [(-4.0, 0.0), (40.0, 24.0), (5.0, 5.0)]
    )
    func setterClamps(value: Double, stored: Double) throws {
        let setting = try SpaceBarCommandSetting.parse(
            field: "glyph_gap",
            args: [.number(value)]
        ).get()
        var style = SpaceBarStyle()
        setting.apply(to: &style)
        #expect(style.glyphGap == CGFloat(stored))
    }

    @Test("A reader clamps whatever wrote the value")
    func readerClamps() {
        var style = SpaceBarStyle()
        style.glyphGap = 90
        #expect(style.resolvedGlyphGap == 24)
    }

    /// One gap between each pair of neighbouring slots — three
    /// glyphs and the badge are four slots, three gaps.
    @Test("The measured length adds one gap per slot boundary")
    @MainActor
    func lengthCountsGaps() {
        let flush = SpaceBarItemView.autoLength(
            appCount: 3,
            overflow: 2,
            depth: 32,
            glyphGap: 0
        )
        let spaced = SpaceBarItemView.autoLength(
            appCount: 3,
            overflow: 2,
            depth: 32,
            glyphGap: 5
        )
        // Three glyphs and the badge: four slots, three gaps.
        let gaps: CGFloat = 3 * 5
        #expect(spaced - flush == gaps)
        #expect(
            SpaceBarItemView.autoLength(
                appCount: 1,
                depth: 32,
                glyphGap: 5
            )
                == SpaceBarItemView.autoLength(
                    appCount: 1,
                    depth: 32,
                    glyphGap: 0
                )
        )
    }
}

/// The item view draws what its length measured: glyph cells and
/// the `+n` badge sit a cell plus the gap apart.
@Suite("Glyph gap reaches the Space item")
@MainActor
struct GlyphGapDrawingTests {
    private static let depth: CGFloat = 32
    private static let gap: CGFloat = 5

    init() { LiquidGlassGate.override = { false } }

    private static func icon() -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) {
            NSColor.black.setFill()
            $0.fill()
            return true
        }
    }

    private func item() -> SpaceBarItemView {
        var look = SpaceBarLook()
        look.glyphGap = Self.gap
        let apps = ["A", "B", "C"].map {
            SpaceBarItemView.App(
                name: $0,
                icon: Self.icon(),
                glyph: nil,
                focused: false,
                count: 1
            )
        }
        let length = SpaceBarItemView.autoLength(
            appCount: apps.count,
            overflow: 2,
            depth: Self.depth,
            glyphGap: look.resolvedGlyphGap
        )
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: length, height: Self.depth)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: apps,
            active: true,
            horizontal: true,
            style: look,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            ),
            overflow: 2
        )
        view.layout()
        return view
    }

    @Test("Neighbouring glyphs sit a cell plus the gap apart")
    func glyphsSpaced() {
        let view = item()
        let pitch = view.cellLength + Self.gap
        let mids = view.appViews.map(\.frame.midX)
        #expect(mids.count == 3)
        for (a, b) in zip(mids, mids.dropFirst()) {
            #expect(abs(b - a - pitch) < 0.5)
        }
    }

    @Test("The +n badge sits a cell plus the gap past the last glyph")
    func badgeSpaced() throws {
        let view = item()
        let last = try #require(view.appViews.last)
        #expect(!view.overflowBadge.isHidden)
        #expect(
            abs(
                view.overflowBadge.frame.midX - last.frame.midX
                    - (view.cellLength + Self.gap)
            ) < 0.5
        )
    }
}

/// The live render: `SpaceBarManager.sync` lays each item out at
/// the length its glyphs and gaps need, and the walk inside ends
/// where that length says — the render's own `itemLengths` call.
@Suite("Glyph gap reaches the rendered Space Bar", .serialized)
@MainActor
struct GlyphGapRenderTests {
    private static let gap: CGFloat = 5

    @Test("Each rendered item is as long as its glyphs and gaps")
    func renderedLengths() throws {
        LiquidGlassGate.override = { false }
        var style = SpaceBarLook()
        style.glyphGap = Self.gap
        style.liquidGlass = false
        let apps = ["A", "B", "C"].map {
            SpaceBarItemView.App(
                name: $0,
                icon: nil,
                glyph: nil,
                focused: false,
                count: 1
            )
        }
        let items = [
            SpaceBarOverlay.Item(
                space: SpaceID("1"),
                spaceGlyph: .text("1", tinted: true),
                apps: apps,
                active: true,
                overflow: 2,
                focusInOverflow: false
            ),
            SpaceBarOverlay.Item(
                space: SpaceID("2"),
                spaceGlyph: .text("2", tinted: true),
                apps: [],
                active: false,
                overflow: 0,
                focusInOverflow: false
            ),
        ]
        let manager = SpaceBarManager()
        manager.sync([
            SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: items,
                strip: barTitleStrip,
                style: style,
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let depth = barTitleStrip.height
        for (index, item) in items.enumerated() {
            let view = overlay.itemViews[index]
            #expect(
                view.frame.width
                    == SpaceBarItemView.autoLength(
                        appCount: item.apps.count,
                        overflow: item.overflow,
                        depth: depth,
                        glyphGap: Self.gap
                    )
            )
        }
        // The walk ends where the length says: the badge's cell
        // closes one pad short of the item's far end.
        let first = overlay.itemViews[0]
        // AppKit lays a resized view out on the next pass; run it.
        first.layoutSubtreeIfNeeded()
        let badge = first.overflowBadge
        #expect(!badge.isHidden)
        let slack =
            badge.frame.midX + first.cellLength / 2
            + SpaceBarItemView.pad - first.bounds.width
        #expect(abs(slack) < 0.5, "badge cell ends \(slack) off")
    }
}

/// The shelf plans the Space Bar's length with the same gap its
/// items draw (`KiwiCore.shelfPlan`).
@Suite("Glyph gap reaches the shelf plan")
@MainActor
struct GlyphGapPlanTests {
    private func spaceSegment(gap: CGFloat) -> CGFloat {
        let core = makeTestCore()
        var settings = core.tiler.settings
        settings.spaceBarStyle.glyphGap = gap
        let apps = ["A", "B", "C"].map {
            SpaceBarItemView.App(
                name: $0,
                icon: nil,
                glyph: nil,
                focused: false,
                count: 1
            )
        }
        let items = (1...2).map {
            SpaceBarOverlay.Item(
                space: SpaceID("\($0)"),
                spaceGlyph: .text("\($0)", tinted: false),
                apps: apps,
                active: $0 == 1,
                overflow: 0,
                focusInOverflow: false
            )
        }
        // An App Bar beside it, so the Space Bar's slot is its
        // own need rather than the whole edge.
        let windows = (1...2).map {
            AppBarOverlay.Item(
                id: WindowID(UInt32($0)),
                text: "Window \($0)",
                icon: nil
            )
        }
        let app = KiwiCore.AppBarContent(
            space: Space(id: "s", windows: []),
            style: settings.appBarLook(for: settings.monocle.appBar),
            groups: windows.map { [$0.id] },
            items: windows
        )
        let plan = core.shelfPlan(
            visible: CGRect(x: 0, y: 0, width: 3000, height: 800),
            settings: settings,
            spaceItems: items,
            app: app
        )
        guard let slot = plan.arrangement.space else { return -1 }
        return plan.segment(slot).width
    }

    /// Two Spaces of three glyphs: two gaps each.
    @Test("The planned length grows by the items' gaps")
    func planCountsGaps() {
        let gaps: CGFloat = 2 * 2 * 5
        #expect(spaceSegment(gap: 5) - spaceSegment(gap: 0) == gaps)
    }
}
