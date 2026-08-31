import AppKit

/// Shared divider geometry and color rendering for Space Bar.
enum BarDivider {
    /// Width of front-app section break divider.
    static let sectionThickness: CGFloat = 2

    /// Returns divider color applying SpaceBarStyle.dividerAlpha.
    static func color(textColor: String) -> NSColor {
        NSColor(kiwiHex: textColor)
            .withAlphaComponent(SpaceBarStyle.dividerAlpha)
    }

    /// Computes divider frame at offset along bar axis.
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
