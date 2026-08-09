import Foundation

/// Whether a palette is the one a config is currently wearing
/// (#757).
///
/// A palette paints one-shot (#375), so nothing records which one
/// was applied — and a "last applied" note would go on lying the
/// moment the user edits a colour by hand. The shelf therefore
/// asks the only question it can answer truthfully: do these
/// colours still say what this palette says?
///
/// Note *these* rather than "the live colours": the shelf passes
/// the config it is EDITING, so with unsaved edits the mark
/// follows the draft rather than the running app. That is the
/// right half — every other preview on the page reads the draft
/// too, and a mark that ignored it would contradict the scene
/// drawn beside it.
extension ColorPalette {
    /// True when every colour this palette paints already carries
    /// this palette's value in `settings`.
    public func isApplied(to settings: TilingSettings) -> Bool {
        isApplied(matching: ColorPaletteKeys.extract(from: settings))
    }

    /// The same answer against an already-extracted colour map.
    ///
    /// Extraction encodes the whole of `TilingSettings` and walks
    /// the result, so a shelf asking per tile would pay that once
    /// per palette per redraw; it extracts once and asks each
    /// palette. The overload exists for that and nothing else —
    /// the answer is still computed, never stored, because a
    /// remembered "applied palette" is the second source of truth
    /// this design refuses.
    ///
    /// Compares what the palette *sets*, not the whole surface: a
    /// sparse palette that paints four colours is applied when
    /// those four match, which is exactly what applying it would
    /// leave behind. A consequence worth stating, since it is
    /// visible: more than one card can be applied at once — a
    /// palette saved from the colours a bundled one painted is
    /// equal to it, and both are honestly "what you have".
    ///
    /// Comparison is by parsed colour rather than by string, so
    /// `#8db354`, `#8DB354` and `#8DB354FF` are one answer — the
    /// hex a user types in Advanced Colours must not read as a
    /// different theme from the hex the palette shipped. The two
    /// mark tints may also carry the empty "Automatic" face
    /// (`ColorPaletteKeys.allowsAutomatic`), which parses to no
    /// colour at all and so is matched as itself.
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

    /// Equal as colours: both empty, or both parse to the same
    /// components. An unparseable hex matches only an identical
    /// unparseable one, which keeps a malformed palette from
    /// reading as applied to anything.
    static func sameColor(_ a: String, _ b: String) -> Bool {
        let left = DragVisual.parseHex(a)
        let right = DragVisual.parseHex(b)
        if let left, let right { return left == right }
        return left == nil && right == nil
            && a.caseInsensitiveCompare(b) == .orderedSame
    }
}
