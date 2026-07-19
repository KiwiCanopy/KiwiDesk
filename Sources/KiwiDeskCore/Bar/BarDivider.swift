import AppKit

/// The 1 pt divider rule the Space Bar draws — between a
/// space's identifier and its app glyphs, and before the
/// trailing front-app segment. Geometry AND color live here so
/// the two rules can't drift (QA 2026-07-19).
enum BarDivider {
    /// The rule's color: the muted `text_color` tier at the
    /// shared divider alpha — structural chrome, never a
    /// state-driven accent.
    static func color(textColor: String) -> NSColor {
        NSColor(kiwiHex: textColor)
            .withAlphaComponent(SpaceBarStyle.dividerAlpha)
    }

    /// The rule's frame at `offset` along the bar axis,
    /// spanning `cell` across, centered in `depth`.
    static func frame(
        at offset: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool
    ) -> CGRect {
        let inset = (depth - cell) / 2
        return horizontal
            ? CGRect(
                x: offset,
                y: inset,
                width: 1,
                height: cell
            )
            : CGRect(
                x: inset,
                y: offset,
                width: cell,
                height: 1
            )
    }
}
