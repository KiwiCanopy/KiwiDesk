import Foundation

/// A named bar text weight (#1681), Apple's nine names on the
/// 100–900 scale. The stored weight is a number; a name is only
/// how Lua may spell one and how a chip or caption names one.
public enum BarFontWeight: String, CaseIterable, Sendable,
    APIChoiceType
{
    case ultralight, thin, light, regular, medium, semibold, bold,
        heavy, black

    /// The weight on the 100–900 scale.
    public var value: Int {
        (Self.allCases.firstIndex(of: self)! + 1) * 100
    }

    /// The five the Settings row offers as chips (ui-designer).
    public static let chips: [BarFontWeight] = [
        .light, .regular, .medium, .semibold, .bold,
    ]

    /// The name a spelling means — case, spaces and hyphens
    /// ignored, so `"Semibold"` and `"semi-bold"` both land.
    public static func named(_ spelling: String) -> BarFontWeight? {
        let key = spelling.lowercased().filter(\.isLetter)
        return allCases.first { $0.rawValue == key }
    }

    /// The named weight closest to `weight`, a tie going to the
    /// lighter.
    public static func nearest(to weight: Int) -> BarFontWeight {
        allCases.min {
            abs($0.value - weight) < abs($1.value - weight)
        }!
    }
}

extension KiwiShelf {
    /// The stored family naming the system UI face — today's
    /// look, and the default.
    public static let systemFontFamily = "System"
    /// The stored family naming the system monospaced face.
    public static let systemMonospacedFontFamily = "System Monospaced"
    /// The two families every Mac has, pinned first in a picker.
    public static let systemFontFamilies = [
        systemFontFamily, systemMonospacedFontFamily,
    ]
    /// Bounds of `fontWeight`.
    public static let fontWeightRange: ClosedRange<Int> = 100...900

    /// A weight rounded and clamped to `fontWeightRange`.
    public static func clampFontWeight(_ weight: Double) -> Int {
        guard weight.isFinite else { return BarFontWeight.regular.value }
        return min(
            max(Int(weight.rounded()), fontWeightRange.lowerBound),
            fontWeightRange.upperBound
        )
    }

    /// `fontWeight` inside `fontWeightRange` — what a drawing asks.
    public var resolvedFontWeight: Int {
        Self.clampFontWeight(Double(fontWeight))
    }
}
