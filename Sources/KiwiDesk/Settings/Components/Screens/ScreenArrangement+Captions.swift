import CoreGraphics
import KiwiDeskCore

/// A split card's area names under the card (#3697, ui-designer
/// 2026-11-27): one line per area top edge, each name under its own
/// area's span, so the card holds only the drop targets.
extension ScreenArrangement {
    /// One area's place in a caption line: its id and unit rect.
    typealias Caption = (id: Int, rect: CGRect)

    /// The caption lines of `split`, top to bottom: the areas
    /// sharing a top edge on one line, left to right. Empty for a
    /// whole screen, whose header already names it; at most
    /// `captionLineCap` lines.
    static func captionLines(of split: ScreenSplit?) -> [[Caption]] {
        guard let split, !split.isWhole else { return [] }
        let units = unitAreas(of: split)
        let tops = Set(units.map { ($0.rect.minY * 1000).rounded() })
            .sorted()
            .prefix(captionLineCap)
        return tops.map { top in
            units.filter { ($0.rect.minY * 1000).rounded() == top }
                .sorted { $0.rect.minX < $1.rect.minX }
        }
    }

    static let captionLineCap = 3
    /// One caption line's height.
    static let captionLine: CGFloat = 13
    static let captionSpacing: CGFloat = 2
    /// The narrowest column that draws its name: an ellipsis alone
    /// names nothing.
    static let captionMinWidth: CGFloat = 28
    /// Where the captions start under the card: past the stand,
    /// drawn or not, so captions line up across a row.
    static let captionTop: CGFloat = standDepth + 2

    /// How far under its card a split card's captions reach; 0 for
    /// a whole screen.
    static func captionReach(of split: ScreenSplit?) -> CGFloat {
        let lines = CGFloat(captionLines(of: split).count)
        guard lines > 0 else { return 0 }
        return captionTop + lines * captionLine
            + (lines - 1) * captionSpacing
    }

    /// `cards` with every card under a split card moved down past
    /// that card's captions, so no caption lands on a card. Cards
    /// side by side keep their places.
    static func reservingCaptions(
        _ cards: [Drawn],
        splits: [String: ScreenSplit]
    ) -> [Drawn] {
        var rects = cards.map(\.rect)
        let order = rects.indices.sorted { rects[$0].minY < rects[$1].minY }
        for index in order {
            let reach = captionReach(
                of: splits[cards[index].display.fingerprint]
            )
            guard reach > 0 else { continue }
            let card = rects[index]
            let band = CGRect(
                x: card.minX,
                y: card.maxY,
                width: card.width,
                height: reach
            )
            for other in order where other != index {
                let below = rects[other]
                guard below.minY >= card.maxY - 0.5,
                    below.intersects(band)
                else { continue }
                let shift = card.maxY + reach - below.minY
                let from = below.minY - 0.5
                for moved in rects.indices where rects[moved].minY >= from {
                    rects[moved] = rects[moved].offsetBy(dx: 0, dy: shift)
                }
            }
        }
        return zip(cards, rects).map {
            Drawn(display: $0.display, rect: $1)
        }
    }
}
