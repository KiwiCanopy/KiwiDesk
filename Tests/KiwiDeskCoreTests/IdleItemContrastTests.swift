import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// An idle Space identifier stays legible (#1517): it is the
/// shelf's item colour at `KiwiShelf.idleItemAlpha`, a rule rather
/// than a palette colour, so the rule is what has to hold on every
/// bundled palette. Measured the way `BorderRingSeparationTests`
/// measures a ring: the plate composited over each wallpaper
/// extreme, the idle ink composited over that plate.
@Suite("Idle item contrast")
struct IdleItemContrastTests {
    /// The ring suite's own-contrast floor, which the idle alpha
    /// was chosen against (ui-designer, #1517): at 0.4 five
    /// palettes fell to about 2:1 or below. Core's one copy, which
    /// The collapsed empty ink keeps too (#1683).
    private static let floor = KiwiShelf.idleInkFloor

    private func idleContrast(
        item: String,
        fill: String,
        on wallpaper: String
    ) -> Double? {
        var shelf = KiwiShelf()
        shelf.itemColor = item
        guard let plate = ColorVision.composite(fill, over: wallpaper),
            let ink = ColorVision.composite(
                shelf.idleItemColor,
                over: plate
            )
        else { return nil }
        return ColorVision.contrast(ink, plate)
    }

    @Test("Every bundled palette's idle identifier clears the floor")
    func idleIdentifiersStayLegible() throws {
        #expect(!PaletteCatalog.authored().isEmpty)
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            let item = try #require(
                palette.colors["kiwishelf.item_color"],
                Comment(rawValue: palette.name)
            )
            let fill = try #require(
                palette.colors["kiwishelf.fill_color"],
                Comment(rawValue: palette.name)
            )
            for wallpaper in ["#FFFFFF", "#000000"] {
                let contrast = try #require(
                    idleContrast(item: item, fill: fill, on: wallpaper)
                )
                #expect(
                    contrast >= Self.floor,
                    Comment(
                        rawValue:
                            "\(palette.name) on \(wallpaper): "
                            + "\(contrast)"
                    )
                )
                measured += 1
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 2)
    }

    /// The idle ink is relative to the colour's own alpha, so a
    /// translucent item colour dims further rather than being
    /// pinned to one absolute alpha.
    @Test("The idle ink scales the item colour's own alpha")
    func idleInkIsRelative() {
        // Derived from the constant, so a retune moves no clause.
        let idle = { (alpha: Int) in
            String(
                format: "%02X",
                Int((CGFloat(alpha) * KiwiShelf.idleItemAlpha).rounded())
            )
        }
        var shelf = KiwiShelf()
        shelf.itemColor = "#EAF3EE"
        #expect(shelf.idleItemColor == "#EAF3EE" + idle(255))
        shelf.itemColor = "#eaf3ee80"
        #expect(shelf.idleItemColor == "#EAF3EE" + idle(0x80))
        #expect(idle(0x80) != idle(255))
        shelf.itemColor = "not a colour"
        #expect(shelf.idleItemColor == "not a colour")
    }

    /// The consumer: an idle text identifier on the live bar is
    /// drawn in `idleItemColor`, the active one is not. The idle
    /// Space holds a window: an empty one takes the empty ink
    /// (`SpaceBarCollapsedRenderTests`).
    @Test("The live bar draws an idle identifier in the idle ink")
    @MainActor
    func liveBarDrawsTheIdleInk() throws {
        LiquidGlassGate.override = { false }
        let manager = SpaceBarManager()
        let painted = paintedSpaceBar(front: nil, spaces: 3)
        let bar = SpaceBarManager.Bar(
            display: painted.display,
            items: painted.items.map { item in
                SpaceBarOverlay.Item(
                    space: item.space ?? SpaceID("1"),
                    spaceGlyph: item.spaceGlyph,
                    apps: [
                        SpaceBarItemView.App(
                            name: "Mail",
                            icon: nil,
                            glyph: nil,
                            focused: false,
                            count: 1
                        )
                    ],
                    active: item.active,
                    overflow: [],
                    focusInOverflow: false
                )
            },
            frontApp: painted.frontApp,
            frontWindow: painted.frontWindow,
            strip: painted.strip,
            style: painted.style,
            stateMarkColors: painted.stateMarkColors
        )
        manager.sync([bar])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let idle = try #require(
            overlay.itemViews.first { !$0.isActive && $0.space != nil }
        )
        let expected = NSColor(kiwiHex: idle.style.idleItemColor)
        let drawn = try #require(idle.identifierLabel.textColor)
        #expect(drawn == expected)
    }
}
