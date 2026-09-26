import CoreGraphics
import Foundation

/// The empty Space's identifier ink under the Space Bar's
/// Minimal content (#1683): derived from the palette, never
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
    static let inkGrounds = ["#FFFFFF", "#000000"]

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
            guard let step = worstContrast(occupied, ink),
                step >= Self.emptyInkStep
            else { continue }
            guard let floor = worstContrast(ink, nil),
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
    /// and `other` (the plate where nil), each composited over
    /// the plate; nil where a colour does not parse.
    private func worstContrast(_ ink: String, _ other: String?) -> Double? {
        var worst: Double?
        for ground in Self.inkGrounds {
            guard let plate = Self.composite(fillColor, over: ground),
                let a = Self.composite(ink, over: plate),
                let b = other.map({ Self.composite($0, over: plate) })
                    ?? plate,
                let ratio = Self.contrast(a, b)
            else { return nil }
            worst = min(worst ?? ratio, ratio)
        }
        return worst
    }

    /// `top` over an opaque `bottom`, mixed on the sRGB bytes the
    /// window server blends, as an opaque hex.
    static func composite(_ top: String, over bottom: String) -> String? {
        guard let over = DragVisual.parseHex(top),
            let under = DragVisual.parseHex(bottom)
        else { return nil }
        let a = over.alpha
        let mix = [
            (over.red, under.red), (over.green, under.green),
            (over.blue, under.blue),
        ]
        .map { Int((($0.0 * a + $0.1 * (1 - a)) * 255).rounded()) }
        return "#" + mix.map { String(format: "%02X", $0) }.joined()
    }

    /// WCAG contrast ratio of two opaque colours, 1...21.
    static func contrast(_ a: String, _ b: String) -> Double? {
        guard let x = luminance(a), let y = luminance(b) else {
            return nil
        }
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    private static func luminance(_ hex: String) -> Double? {
        guard let c = DragVisual.parseHex(hex) else { return nil }
        let linear = { (v: Double) in
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green)
            + 0.0722 * linear(c.blue)
    }
}
