import CoreGraphics
import Foundation

/// The identifier ink of an empty Space the screen does not show
/// (#1683): derived from the palette, never
/// picked, and dropped where the palette cannot fit it.
extension KiwiShelf {
    /// Contrast an idle identifier holds on its plate over white
    /// and black wallpaper (#1517). The empty ink keeps it too:
    /// it is still an identifier the user reads.
    public static let idleInkFloor = 2.2

    /// Contrast an occupied idle identifier holds over an empty
    /// one, on both wallpapers. The cue tells two states of one
    /// hue apart at a glance, so it is a step rather than a
    /// reading floor; 1.3:1 is the step ruled on #1683, and a
    /// retune measures it on the device, beside a neighbour.
    public static let emptyInkStep = 1.3

    /// The wallpaper extremes every ink is measured over.
    private static let inkGrounds = ["#FFFFFF", "#000000"]

    /// The share of `itemColor`'s own alpha an empty identifier
    /// draws at, or nil where no share holds both
    /// `emptyInkStep` under the idle ink and `idleInkFloor` on
    /// the plate: the cue drops rather than the floor. The
    /// candidate is the least dimming that makes the step, since
    /// dimming further only loses contrast on the plate.
    public var emptyItemAlpha: CGFloat? {
        let occupied = idleItemColor
        let top = Int((Self.idleItemAlpha * 100).rounded()) - 1
        guard top >= 0 else { return nil }
        for hundredths in stride(from: top, through: 0, by: -1) {
            let share = CGFloat(hundredths) / 100
            let ink = itemColor(atShare: share)
            guard let step = worstContrast(occupied, ink, on: fillColor),
                step >= Self.emptyInkStep
            else { continue }
            guard let floor = worstContrast(ink, nil, on: fillColor),
                floor >= Self.idleInkFloor
            else { return nil }
            return share
        }
        return nil
    }

    /// The ink an empty Space's identifier draws in: the idle
    /// ink where the palette cannot carry the cue.
    public var emptyItemColor: String {
        emptyItemAlpha.map { itemColor(atShare: $0) } ?? idleItemColor
    }

    /// The lower of the two wallpapers' contrasts between `ink`
    /// and `other` (the plate where nil), each composited over the
    /// plate `fill` — and over `layer` on that plate where given,
    /// as a badge fill is; nil where a colour does not parse.
    func worstContrast(
        _ ink: String,
        _ other: String?,
        on fill: String,
        beneath layer: String? = nil
    ) -> Double? {
        var worst: Double?
        for ground in Self.inkGrounds {
            guard let shelf = ColorVision.composite(fill, over: ground),
                let plate = layer.map({
                    ColorVision.composite($0, over: shelf)
                }) ?? shelf,
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
}
