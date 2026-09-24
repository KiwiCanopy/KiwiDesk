import AppKit

/// Shared divider geometry and color rendering for Space Bar.
enum BarDivider {
    /// Width of front-app section break divider — heavier than
    /// the 1 pt in-chip rule so the boundary reads as a bigger
    /// separation (QA 2026-07-19).
    static let sectionThickness: CGFloat = 2

    /// The divider ladder's lengths, as a share of the depth
    /// (#1517, ui-designer): the rule inside a Space item is the
    /// shortest; the layer and front-app breaks and the shelf's
    /// section divider share the longer one, alpha ranking them
    /// (`ShelfDividerWeightTests`). Never full depth — a full-height
    /// line splits the plate it stands on.
    static let ruleLengthShare: CGFloat = 0.5
    static let sectionLengthShare: CGFloat = 0.7

    /// The shelf's section divider colour (#1517).
    static func sectionColor(textColor: String) -> NSColor {
        NSColor(kiwiHex: textColor)
            .withAlphaComponent(SpaceBarStyle.sectionDividerAlpha)
    }

    /// Returns divider color applying SpaceBarStyle.dividerAlpha.
    static func color(textColor: String) -> NSColor {
        NSColor(kiwiHex: textColor)
            .withAlphaComponent(SpaceBarStyle.dividerAlpha)
    }

    /// Computes divider frame at offset along bar axis.
    static func frame(
        at offset: CGFloat,
        depth: CGFloat,
        horizontal: Bool,
        thickness: CGFloat = 1,
        lengthShare: CGFloat = ruleLengthShare
    ) -> CGRect {
        let span = depth * lengthShare
        let inset = (depth - span) / 2
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
