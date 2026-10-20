import CoreGraphics
import Foundation

/// The grow (#761), the `reveal_style` beside the slide (owner
/// ruling, 2026-10-21): the plate grows out of the hidden mark and
/// the items fade up on it, and back. Its timings and its pure
/// decision; `BarMotion.playReveal`, the gated home, plays it.
enum ShelfGrow {
    /// A grow's two channels, timed from the motion's start: a clip
    /// from `mark` to `plate` (the content layer's own coordinates)
    /// and the items' fade.
    struct Morph: Equatable {
        let entering: Bool
        let mark: CGRect
        let plate: CGRect
        let markRadius: CGFloat
        let plateRadius: CGFloat
        let plateStart: TimeInterval
        let plateLength: TimeInterval
        let itemsStart: TimeInterval
        let itemsLength: TimeInterval
        /// Until both channels have landed.
        let length: TimeInterval
    }

    /// The grow's timings (ruling on #761): the plate grows over
    /// `plateGrow` while the items fade up over `itemsFadeIn` from
    /// `itemsDelay`; a retract fades the items over `itemsFadeOut`
    /// and then shrinks the plate over `plateShrink`.
    static let plateGrow: TimeInterval = 0.24
    static let itemsDelay: TimeInterval = 0.08
    static let itemsFadeIn: TimeInterval = 0.16
    static let itemsFadeOut: TimeInterval = 0.08
    static let plateShrink: TimeInterval = 0.18
    /// A retract's whole length: the items out, then the plate.
    static let retractLength = itemsFadeOut + plateShrink

    /// The grow out of or into `mark` — the mark at its hovered
    /// size, which `BarMotion.revealMotion` hands it — onto `plate`.
    static func morph(
        entering: Bool,
        mark: CGRect,
        plate: CGRect,
        plateRadius: CGFloat
    ) -> Morph {
        let plateStart = entering ? 0 : itemsFadeOut
        let plateLength = entering ? plateGrow : plateShrink
        let itemsStart = entering ? itemsDelay : 0
        let itemsLength = entering ? itemsFadeIn : itemsFadeOut
        return Morph(
            entering: entering,
            mark: mark,
            plate: plate,
            markRadius: min(mark.width, mark.height) / 2,
            plateRadius: plateRadius,
            plateStart: plateStart,
            plateLength: plateLength,
            itemsStart: itemsStart,
            itemsLength: itemsLength,
            length: max(plateStart + plateLength, itemsStart + itemsLength)
        )
    }
}
