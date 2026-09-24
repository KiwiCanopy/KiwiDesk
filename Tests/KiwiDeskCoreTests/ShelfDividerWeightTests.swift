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
}
