import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The shelf's section divider outranks the rule inside a Space
/// item and stays quieter than idle ink (#1517). The owner found
/// a divider at the in-item rule's weight too faint to read as
/// the boundary between two bars, which is why a floor is pinned
/// beside the ordering.
@Suite("Shelf divider weight")
struct ShelfDividerWeightTests {
    @Test("Heavier than the in-item rule, quieter than idle ink")
    func ordering() {
        #expect(BarDivider.ruleAlpha < BarDivider.sectionAlpha)
        #expect(BarDivider.sectionAlpha < KiwiShelf.idleItemAlpha)
        #expect(BarDivider.sectionThickness > 1)
        // Lengths ladder too: the in-item rule is the shortest,
        // and nothing spans the full depth.
        #expect(BarDivider.ruleLengthShare < BarDivider.sectionLengthShare)
        #expect(BarDivider.sectionLengthShare < 1)
    }

    /// Measured as `IdleItemContrastTests` measures idle ink: the
    /// plate over each wallpaper extreme, the divider ink over it.
    @Test("Every bundled palette's divider clears 2:1 on its plate")
    func dividerFloor() throws {
        #expect(!PaletteCatalog.authored().isEmpty)
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            let item = try #require(palette.colors["kiwishelf.item_color"])
            let fill = try #require(palette.colors["kiwishelf.fill_color"])
            let rgb = item.uppercased().drop { $0 == "#" }.prefix(6)
            let alpha = Int(
                (BarDivider.sectionAlpha * 255).rounded()
            )
            let ink = "#" + rgb + String(format: "%02X", alpha)
            for wallpaper in ["#FFFFFF", "#000000"] {
                let plate = try #require(
                    ColorVision.composite(fill, over: wallpaper)
                )
                let line = try #require(
                    ColorVision.composite(ink, over: plate)
                )
                let contrast = try #require(
                    ColorVision.contrast(line, plate)
                )
                #expect(
                    contrast >= 2.0,
                    Comment(
                        rawValue:
                            "\(palette.name) on \(wallpaper): \(contrast)"
                    )
                )
                measured += 1
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 2)
    }

    /// The consumers take the ladder's alphas, not a copy: the
    /// shelf's live divider draws at the section alpha, the rule
    /// and breaks at the rule alpha.
    @Test("The drawn divider takes the section alpha")
    @MainActor
    func drawnDividerTakesTheLadder() throws {
        #expect(
            BarDivider.sectionColor(textColor: "#FFFFFF").alphaComponent
                == BarDivider.sectionAlpha
        )
        #expect(
            BarDivider.color(textColor: "#FFFFFF").alphaComponent
                == BarDivider.ruleAlpha
        )
        let overlay = ShelfOverlay()
        let strip = CGRect(x: 0, y: 0, width: 400, height: 30)
        overlay.show(
            strip: strip,
            shelf: KiwiShelf(),
            sections: [
                .init(
                    view: NSView(),
                    slot: CGRect(x: 0, y: 0, width: 200, height: 30),
                    plate: .zero
                ),
                .init(
                    view: NSView(),
                    slot: CGRect(x: 200, y: 0, width: 200, height: 30),
                    plate: .zero
                ),
            ]
        )
        let ink = try #require(overlay.divider.layer?.backgroundColor)
        #expect(ink.alpha == BarDivider.sectionAlpha)
        #expect(overlay.divider.frame.width == BarDivider.sectionThickness)
        #expect(
            overlay.divider.frame.height
                == strip.height * BarDivider.sectionLengthShare
        )
        overlay.hide()
    }

    /// The rule's consumers draw at the rule alpha: the in-item
    /// rule, and the front-app and layer breaks — never the section
    /// divider's heavier ink.
    @Test("The rules and breaks take the rule alpha")
    @MainActor
    func rulesTakeTheRuleAlpha() throws {
        LiquidGlassGate.override = { false }
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: WindowID(1), spaces: 3)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let item = try #require(overlay.itemViews.first)
        let rule = try #require(item.identifierDivider.layer?.backgroundColor)
        #expect(rule.alpha == BarDivider.ruleAlpha)
        let front = try #require(overlay.frontDivider.layer?.backgroundColor)
        #expect(front.alpha == BarDivider.ruleAlpha)
    }

    /// Owner 2026-09-25: a draggable divider must show it can be
    /// grabbed. Hovering the live grip draws the line in the hover
    /// ink at full strength, at its resting weight; leaving
    /// restores the ladder's ink.
    @Test("The draggable divider shows its hover")
    @MainActor
    func draggableDividerHovers() throws {
        var shelf = KiwiShelf()
        shelf.hoverItemColor = "#FF0000"
        let overlay = ShelfOverlay()
        let strip = CGRect(x: 0, y: 0, width: 1000, height: 30)
        let full = try #require(
            ShelfArrangement.arrange(
                length: 1000,
                spaceNeed: 700,
                appNeed: 900,
                spaceFloor: 100,
                shelf: shelf
            ).divider
        )
        let sections: [ShelfOverlay.Section] = [
            .init(
                view: NSView(),
                slot: CGRect(x: 0, y: 0, width: 300, height: 30),
                plate: .zero
            ),
            .init(
                view: NSView(),
                slot: CGRect(x: 300, y: 0, width: 700, height: 30),
                plate: .zero
            ),
        ]
        overlay.show(
            strip: strip,
            shelf: shelf,
            sections: sections,
            divider: full
        )
        let rest = overlay.divider.frame
        #expect(rest.width == BarDivider.sectionThickness)
        overlay.handle.setHovered(true)
        // Ink only: the resize cursor carries the rest (owner
        // 2026-09-25), so the line keeps its weight.
        #expect(overlay.divider.frame == rest)
        // A relayout while hovered keeps the weight too.
        overlay.show(
            strip: strip,
            shelf: shelf,
            sections: sections,
            divider: full
        )
        #expect(overlay.divider.frame == rest)
        #expect(overlay.handle.isHovered)
        let ink = try #require(overlay.divider.layer?.backgroundColor)
        #expect(ink.alpha == 1)
        #expect(
            NSColor(cgColor: ink)?.usingColorSpace(.sRGB)?.redComponent == 1
        )
        overlay.handle.setHovered(false)
        #expect(overlay.divider.frame == rest)
        #expect(
            overlay.divider.layer?.backgroundColor?.alpha
                == BarDivider.sectionAlpha
        )
        overlay.hide()
    }
}
