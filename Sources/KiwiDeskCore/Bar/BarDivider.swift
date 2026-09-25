import AppKit

/// The divider ladder's one home (#1517): every rule a bar
/// draws — inside a Space item, at a layer or front-app break,
/// and between the shelf's two sections — takes its geometry and
/// ink from here (`ShelfDividerWeightTests`).
public enum BarDivider {
    /// The in-item rule's and the breaks' alpha over the item
    /// colour.
    static let ruleAlpha: CGFloat = 0.4

    /// The shelf's section divider alpha: above the rule, below
    /// idle ink, so the boundary between two bars outranks a
    /// detail inside one item without reading as an item.
    static let sectionAlpha: CGFloat = 0.5

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
    public static func sectionColor(textColor: String) -> NSColor {
        NSColor(kiwiHex: textColor)
            .withAlphaComponent(sectionAlpha)
    }

    /// The shelf's section divider centred on `middle` along the
    /// edge, at the section break's weight — the live shelf's and
    /// the Settings preview's one geometry (#1517).
    public static func sectionFrame(
        at middle: CGFloat,
        depth: CGFloat,
        horizontal: Bool
    ) -> CGRect {
        frame(
            at: middle - sectionThickness / 2,
            depth: depth,
            horizontal: horizontal,
            thickness: sectionThickness,
            lengthShare: sectionLengthShare
        )
    }

    /// The hovered divider's colour: the hover ink, opaque.
    static func sectionHoverColor(hoverColor: String) -> NSColor {
        NSColor(kiwiHex: hoverColor).withAlphaComponent(1)
    }

    /// The rule's and the breaks' colour.
    static func color(textColor: String) -> NSColor {
        NSColor(kiwiHex: textColor)
            .withAlphaComponent(ruleAlpha)
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
