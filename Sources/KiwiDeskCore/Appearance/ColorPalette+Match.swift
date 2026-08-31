import Foundation

/// Palette matching against active settings values (#375, #757).
extension ColorPalette {
    /// True when every colour defined in this palette matches `settings`
    /// (`ColorPaletteKeys.extract`, #757).
    public func isApplied(to settings: TilingSettings) -> Bool {
        isApplied(matching: ColorPaletteKeys.extract(from: settings))
    }

    /// Evaluates if palette colors match extracted color map
    /// (`ColorPaletteKeys.allowsAutomatic`, #757).
    public func isApplied(
        matching live: [String: String]
    ) -> Bool {
        guard !colors.isEmpty else { return false }
        return colors.allSatisfy { path, hex in
            guard let current = live[path] else { return false }
            return Self.sameColor(hex, current)
        }
    }

    /// Compares two color strings for equivalent parsed color value
    /// (`DragVisual.parseHex`).
    static func sameColor(_ a: String, _ b: String) -> Bool {
        let left = DragVisual.parseHex(a)
        let right = DragVisual.parseHex(b)
        if let left, let right { return left == right }
        return left == nil && right == nil
            && a.caseInsensitiveCompare(b) == .orderedSame
    }
}
