import CoreGraphics
import KiwiDeskCore

/// A split card's panes and the picture's stands (#3517 rulings
/// 27–29).
extension ScreenArrangement {
    /// Each area of `split` as a share of its screen — the unit
    /// square, y down — in reading order; one whole area 0 where
    /// the split is nil or whole. The extents come from the areas
    /// themselves, which tile the screen exactly.
    static func unitAreas(
        of split: ScreenSplit?
    ) -> [(id: Int, rect: CGRect)] {
        guard let split, !split.isWhole else {
            return [(0, CGRect(x: 0, y: 0, width: 1, height: 1))]
        }
        let width = CGFloat(max(split.extent.width, 1))
        let height = CGFloat(max(split.extent.height, 1))
        return ScreenArea.readingOrder(split.areas).map { area in
            (
                area.id,
                CGRect(
                    x: CGFloat(area.x) / width,
                    y: CGFloat(area.y) / height,
                    width: CGFloat(area.w) / width,
                    height: CGFloat(area.h) / height
                )
            )
        }
    }

    /// A unit area laid on a card of `size`, rounded to whole
    /// points so neighbouring panes share their seam exactly.
    static func paneRect(_ unit: CGRect, in size: CGSize) -> CGRect {
        let minX = (unit.minX * size.width).rounded()
        let minY = (unit.minY * size.height).rounded()
        let maxX = (unit.maxX * size.width).rounded()
        let maxY = (unit.maxY * size.height).rounded()
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    /// Height of the band a stand takes under its card.
    static let standDepth: CGFloat = 12 + SettingsTheme.hoverRise

    /// The cards that keep their stand (ruling 28): a stand centred
    /// under its card that would land on another card is not drawn,
    /// so only the lowest screen in a column keeps its foot.
    static func standing(_ layout: Layout) -> Set<DisplayID> {
        Set(
            layout.displays.filter { drawn in
                let base = ScreensPicture.standBase(
                    cardWidth: drawn.rect.width
                )
                let foot = CGRect(
                    x: drawn.rect.midX - base / 2,
                    y: drawn.rect.maxY,
                    width: base,
                    height: standDepth
                )
                return !layout.displays.contains {
                    $0.id != drawn.id && $0.rect.intersects(foot)
                }
            }
            .map(\.id)
        )
    }
}
