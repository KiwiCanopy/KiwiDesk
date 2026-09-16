import CoreGraphics
import Foundation

/// A share read as a COUNT — the Settings stepper's Core half
/// (#1382). Every count↔share inverse homes here beside the pitch
/// it inverts, so the GUI carries no rounding policy of its own
/// (`ScrollingColumnCapTests`).
extension ScrollSize {
    /// The whole count a share IS — `n` where the share is `1/n`
    /// at the wire's own precision (`percentString`), else nil:
    /// the stepper's "—". No hand-typed tolerance: the catalog
    /// spelling is the one equality.
    public static func count(of fraction: Double) -> Int? {
        guard fraction > 0 else { return nil }
        let n = Int((1 / fraction).rounded())
        guard n >= 1,
            percentString(1 / Double(n)) == percentString(fraction)
        else { return nil }
        return n
    }

    /// The share `count(of:)` reads back as `n`, at the wire's
    /// precision — what the stepper writes, so a stored third
    /// re-read from disk is not a change.
    public static func share(of n: Int) -> Double {
        let percent = String(format: "%.2f", 100 / Double(n))
        return (Double(percent) ?? 100 / Double(n)) / 100
    }

    /// The first whole count at or above an off-count share —
    /// where ▲ lands from "—" (`ceil(1/f)`).
    public static func countAbove(_ fraction: Double) -> Int {
        max(1, Int((1 / fraction).rounded(.up)))
    }

    /// The first whole count at or below an off-count share —
    /// where ▼ lands from "—" (`floor(1/f)`).
    public static func countBelow(_ fraction: Double) -> Int {
        max(1, Int((1 / fraction).rounded(.down)))
    }

    /// How many slots of the pitch fit `along` with each at least
    /// `minimum` — the stepper's ▲ bound, from the terms `metrics`
    /// draws with: `n·minimum + (n − 1)·gap ≤ along`, never past
    /// `countCeiling`, which the write clamps to.
    public static func maxCount(
        along: CGFloat,
        gap: CGFloat,
        minimum: CGFloat
    ) -> Int {
        guard minimum + gap > 0 else { return countCeiling }
        let fit = Int(((along + gap) / (minimum + gap)).rounded(.down))
        return min(max(1, fit), countCeiling)
    }

    /// The most a count can be: the share's own floor, `1 /
    /// minFraction` — the ▲ bound wherever no screen is known.
    public static let countCeiling = Int((1 / minFraction).rounded())
}
