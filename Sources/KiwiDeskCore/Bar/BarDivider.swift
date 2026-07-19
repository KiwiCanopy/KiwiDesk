import AppKit

/// The divider rule the Space Bar draws — between a space's
/// identifier and its app glyphs (a minor sub-separator, 1 pt,
/// cell-height), and before the trailing front-app segment (a
/// top-level section break, `sectionThickness` pt, full bar
/// depth). Geometry AND color live here so the two rules can't
/// drift (QA 2026-07-19); the two callers just pass different
/// weights.
enum BarDivider {
    /// Width of the front-app section-break rule — heavier than
    /// the 1 pt in-chip rule so the spaces-run ┃ front-app
    /// boundary reads as a bigger separation (QA 2026-07-19).
    static let sectionThickness: CGFloat = 2

    /// The rule's color: the muted `item_color` tier at the
    /// shared divider alpha — structural chrome, never a
    /// state-driven accent.
    static func color(textColor: String) -> NSColor {
        NSColor(kiwiHex: textColor)
            .withAlphaComponent(SpaceBarStyle.dividerAlpha)
    }

    /// The rule's frame at `offset` along the bar axis. Spans
    /// `cell` across and centered in `depth` by default (the
    /// in-chip rule); `fullDepth` spans the whole strip edge-to-
    /// edge (the front-app section break). `thickness` is the
    /// along-axis width.
    static func frame(
        at offset: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        thickness: CGFloat = 1,
        fullDepth: Bool = false
    ) -> CGRect {
        let span = fullDepth ? depth : cell
        let inset = fullDepth ? 0 : (depth - cell) / 2
        return horizontal
            ? CGRect(
                x: offset,
                y: inset,
                width: thickness,
                height: span
            )
            : CGRect(
                x: inset,
                y: offset,
                width: span,
                height: thickness
            )
    }
}
