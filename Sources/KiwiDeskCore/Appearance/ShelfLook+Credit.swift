import Foundation

/// The credit rule (#1740): a look keeps crediting the one it
/// started from while half or more of that original's own settings
/// are unchanged. Only the paths the ORIGINAL sets count, each
/// styling path and each colour path once, nothing weighted — the
/// gallery's copy warning reads the same measure (`looksim.py`).
extension ShelfLook {
    /// The share at which a credit stays.
    public static let creditShare = 0.5

    /// The share of this look's own settings `settings` still
    /// carries: a styling path counts when applying it would change
    /// nothing, a colour by parsed value (`ColorPalette.sameColor`).
    /// 0 for a look that names nothing.
    public func keptShare(in settings: TilingSettings) -> Double {
        var total = 0
        var kept = 0
        for path in LookKeys.all {
            guard let value = style[path] else { continue }
            total += 1
            var painted = settings
            Self.apply(path: path, value: value, to: &painted)
            if painted == settings { kept += 1 }
        }
        let current = ColorPaletteKeys.extract(from: settings)
        for path in ColorPaletteKeys.all {
            guard let hex = colors[path] else { continue }
            total += 1
            if ColorPalette.sameColor(hex, current[path] ?? "") {
                kept += 1
            }
        }
        return total == 0 ? 0 : Double(kept) / Double(total)
    }

    /// Whether `settings` still owe this look its credit.
    public func stillCredited(by settings: TilingSettings) -> Bool {
        keptShare(in: settings) >= Self.creditShare
    }
}
