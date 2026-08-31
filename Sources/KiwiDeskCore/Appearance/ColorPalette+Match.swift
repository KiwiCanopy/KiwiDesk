import Foundation

/// Palette matching against active settings values (#375,
/// #757). Computed, never stored: a remembered "last applied"
/// note would go on lying the moment the user edits a colour by
/// hand — the shelf asks the only question it can answer
/// truthfully. The shelf passes the config it is EDITING, so the
/// mark follows the draft like every other preview.
extension ColorPalette {
    /// True when every colour defined in this palette matches `settings`
    /// (`ColorPaletteKeys.extract`, #757).
    public func isApplied(to settings: TilingSettings) -> Bool {
        isApplied(matching: ColorPaletteKeys.extract(from: settings))
    }

    /// Evaluates if palette colors match the extracted map
    /// (`ColorPaletteKeys.allowsAutomatic`, #757). Compares what
    /// the palette SETS, not the whole surface — so more than one
    /// card can honestly read applied at once. Comparison is by
    /// PARSED colour: `#8db354` and `#8DB354FF` are one answer.
    public func isApplied(
        matching live: [String: String]
    ) -> Bool {
        // An empty palette paints nothing, and "nothing is
        // already true" would mark it applied against every
        // possible config.
        guard !colors.isEmpty else { return false }
        return colors.allSatisfy { path, hex in
            guard let current = live[path] else { return false }
            return Self.sameColor(hex, current)
        }
    }

    /// Compares two color strings for equivalent parsed value
    /// (`DragVisual.parseHex`). An unparseable hex matches only an
    /// identical unparseable one, so a malformed palette cannot
    /// read as applied to anything.
    static func sameColor(_ a: String, _ b: String) -> Bool {
        let left = DragVisual.parseHex(a)
        let right = DragVisual.parseHex(b)
        if let left, let right { return left == right }
        return left == nil && right == nil
            && a.caseInsensitiveCompare(b) == .orderedSame
    }
}
