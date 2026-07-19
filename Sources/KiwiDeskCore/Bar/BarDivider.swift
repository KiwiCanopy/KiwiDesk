import AppKit

/// The 1 pt divider rule the Space Bar draws — between a
/// space's identifier and its app glyphs, and before the
/// trailing front-app segment. One geometry helper so the two
/// rules can't drift (QA 2026-07-19); the shared color
/// treatment is `textColor` at `SpaceBarStyle.frontDividerAlpha`.
enum BarDivider {
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
