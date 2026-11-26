import CoreGraphics

/// Where the look picker draws on one screen (#3038 ▸ Ruling
/// 2026-11-23), in the overlay's own top-left coordinates: the
/// selected card, the stripes beside it and the name below. Pure,
/// so a screen size is all a test needs.
struct LookPickerGeometry: Equatable {
    /// The screen the overlay covers.
    let screen: CGSize
    /// The height macOS's menu bar takes off the top.
    let menuBar: CGFloat

    /// The card: 56 % of the width at 16:10, its height capped at
    /// 62 % of the screen, centred a little above the middle.
    var card: CGRect {
        var width = screen.width * Self.cardShare
        var height = width / Self.cardAspect
        if height > screen.height * Self.heightCap {
            height = screen.height * Self.heightCap
            width = height * Self.cardAspect
        }
        let centre = CGPoint(
            x: screen.width / 2,
            y: menuBar + (screen.height - menuBar) * Self.centreShare
        )
        return CGRect(
            x: centre.x - width / 2,
            y: centre.y - height / 2,
            width: width,
            height: height
        )
    }

    /// The card's frosted frame, `framePad` round the card.
    var frame: CGRect {
        card.insetBy(dx: -Self.framePad, dy: -Self.framePad)
    }

    /// How much smaller the card draws the desk than the screen.
    var scale: CGFloat { card.width / max(screen.width, 1) }

    /// A stripe's size: 6 % of the width, 88 % of the card's height.
    var stripeSize: CGSize {
        CGSize(
            width: max(screen.width * Self.stripeShare, Self.stripeFloor),
            height: card.height * Self.stripeHeightShare
        )
    }

    /// The stripes on one side, nearest first: `side` -1 leftward,
    /// +1 rightward, at most `available` of them, each overlapping
    /// the next by a quarter, the first tucked under the card, and
    /// the last one the screen cuts.
    func stripes(side: Int, available: Int) -> [CGRect] {
        let size = stripeSize
        let step = size.width * (1 - Self.stripeOverlap)
        let edge = side > 0 ? card.maxX : card.minX
        var rects: [CGRect] = []
        for k in 0..<max(available, 0) {
            let offset = CGFloat(k) * step
            let x =
                side > 0
                ? edge + offset - size.width * Self.tuck
                : edge - offset - size.width * (1 - Self.tuck)
            rects.append(
                CGRect(
                    x: x,
                    y: card.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
            )
            let next = x + CGFloat(side) * step
            let beyond =
                side > 0
                ? next + size.width > screen.width - Self.margin
                : next < Self.margin
            if beyond { break }
        }
        return rects
    }

    /// The black a stripe `k` steps out wears, darker further out.
    static func stripeShade(_ k: Int) -> Double {
        min(0.25 + 0.08 * Double(k), 0.7)
    }

    /// The name's top, a little below the card.
    var nameTop: CGFloat { card.maxY + card.height * 0.06 }

    /// The name's point size, 34 pt on a laptop, growing with a
    /// wider screen.
    var nameSize: CGFloat { 34 * max(1, screen.width / 1512) }

    static let cardShare: CGFloat = 0.56
    static let cardAspect: CGFloat = 1.6
    static let heightCap: CGFloat = 0.62
    static let centreShare: CGFloat = 0.46
    static let framePad: CGFloat = 12
    static let cardRadius: CGFloat = 14
    static let frameRadius: CGFloat = 26
    static let stripeShare: CGFloat = 0.06
    static let stripeFloor: CGFloat = 70
    static let stripeHeightShare: CGFloat = 0.88
    static let stripeOverlap: CGFloat = 0.25
    static let stripeRadius: CGFloat = 8
    /// How much of the nearest stripe hides under the card.
    static let tuck: CGFloat = 0.35
    static let margin: CGFloat = 24
}
