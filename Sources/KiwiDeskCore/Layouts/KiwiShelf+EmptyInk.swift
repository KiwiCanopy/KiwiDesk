import CoreGraphics
import Foundation
import os

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
    /// Memoised per (item, fill) colour pair, since every bar
    /// pass reads it.
    public var emptyItemAlpha: CGFloat? {
        let key = EmptyInkKey(item: itemColor, fill: fillColor)
        if let hit = Self.emptyInkMemo.withLock({ $0[key] }) {
            return hit
        }
        let share = searchEmptyItemAlpha()
        Self.emptyInkMemo.withLock {
            if $0.count >= Self.emptyInkMemoCap { $0.removeAll() }
            $0.updateValue(share, forKey: key)
        }
        return share
    }

    private struct EmptyInkKey: Hashable, Sendable {
        let item: String
        let fill: String
    }

    /// Distinct palettes stay few; a colour drag mints one key per
    /// step, so the memo clears itself past this many.
    private static let emptyInkMemoCap = 64

    private static let emptyInkMemo =
        OSAllocatedUnfairLock<[EmptyInkKey: CGFloat?]>(initialState: [:])

    private func searchEmptyItemAlpha() -> CGFloat? {
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
