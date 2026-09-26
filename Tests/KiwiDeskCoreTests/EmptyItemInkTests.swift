import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Minimal's empty-Space cue (#1683): an empty Space's
/// identifier draws dimmer than an occupied one's, DERIVED from
/// the palette by `KiwiShelf.emptyItemAlpha`, never picked. The
/// derivation runs on Core's own maths; this suite measures its
/// answer on `ColorVision`, the repo instrument, the way
/// `IdleItemContrastTests` measures the idle ink.
@Suite("Empty item ink")
struct EmptyItemInkTests {
    private static let grounds = ["#FFFFFF", "#000000"]

    /// The lower of the two wallpapers' contrasts between `ink`
    /// and `other` (the plate where nil), on ColorVision.
    private func worst(
        _ ink: String,
        _ other: String?,
        fill: String
    ) -> Double? {
        var worst: Double?
        for ground in Self.grounds {
            guard let plate = ColorVision.composite(fill, over: ground),
                let a = ColorVision.composite(ink, over: plate),
                let b = other.map({
                    ColorVision.composite($0, over: plate)
                }) ?? plate,
                let ratio = ColorVision.contrast(a, b)
            else { return nil }
            worst = min(worst ?? ratio, ratio)
        }
        return worst
    }

    private func shelf(_ palette: ColorPalette) throws -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.itemColor = try #require(
            palette.colors["kiwishelf.item_color"],
            Comment(rawValue: palette.name)
        )
        shelf.fillColor = try #require(
            palette.colors["kiwishelf.fill_color"],
            Comment(rawValue: palette.name)
        )
        return shelf
    }

    /// Whether any share below the idle ink's fits both bounds,
    /// scanned on ColorVision over every alpha byte.
    private func anyShareFits(_ shelf: KiwiShelf) -> Bool {
        let occupied = shelf.idleItemColor
        let top = Int((KiwiShelf.idleItemAlpha * 100).rounded())
        return (0..<top).contains { hundredths in
            let ink = shelf.itemColor(
                atShare: CGFloat(hundredths) / 100
            )
            guard
                let step = worst(occupied, ink, fill: shelf.fillColor),
                let floor = worst(ink, nil, fill: shelf.fillColor)
            else { return false }
            return step >= KiwiShelf.emptyInkStep
                && floor >= KiwiShelf.idleInkFloor
        }
    }

    @Test("Every bundled palette's empty ink holds both bounds or drops")
    func everyPaletteFitsOrDrops() throws {
        #expect(!PaletteCatalog.bundled().isEmpty)
        for palette in PaletteCatalog.bundled() {
            let shelf = try shelf(palette)
            let name = Comment(rawValue: palette.name)
            guard let share = shelf.emptyItemAlpha else {
                // Dropped: no share fits, measured independently,
                // and the empty ink is the idle one.
                #expect(!anyShareFits(shelf), name)
                #expect(shelf.emptyItemColor == shelf.idleItemColor)
                continue
            }
            #expect(share < KiwiShelf.idleItemAlpha, name)
            let ink = shelf.emptyItemColor
            #expect(ink == shelf.itemColor(atShare: share), name)
            let step = try #require(
                worst(shelf.idleItemColor, ink, fill: shelf.fillColor)
            )
            let floor = try #require(
                worst(ink, nil, fill: shelf.fillColor)
            )
            #expect(step >= KiwiShelf.emptyInkStep, name)
            #expect(floor >= KiwiShelf.idleInkFloor, name)
        }
    }

    /// Not vacuous: the shipped look carries the cue.
    @Test("The default shelf carries the cue")
    func defaultShelfCarriesTheCue() {
        let shelf = KiwiShelf()
        #expect(shelf.emptyItemAlpha != nil)
        #expect(shelf.emptyItemColor != shelf.idleItemColor)
    }

    /// A plate the idle ink barely clears leaves no room for a
    /// step: the cue drops, and the floor is never lowered.
    @Test("A palette with no room drops the cue")
    func noRoomDropsTheCue() {
        var shelf = KiwiShelf()
        shelf.itemColor = "#808080"
        shelf.fillColor = "#606060"
        #expect(shelf.emptyItemAlpha == nil)
        #expect(!anyShareFits(shelf))
        #expect(shelf.emptyItemColor == shelf.idleItemColor)
    }
}
