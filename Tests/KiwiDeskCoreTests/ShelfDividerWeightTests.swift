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
        #expect(SpaceBarStyle.dividerAlpha < SpaceBarStyle.sectionDividerAlpha)
        #expect(SpaceBarStyle.sectionDividerAlpha < KiwiShelf.idleItemAlpha)
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
                (SpaceBarStyle.sectionDividerAlpha * 255).rounded()
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
}
