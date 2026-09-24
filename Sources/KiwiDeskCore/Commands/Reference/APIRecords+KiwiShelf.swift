import Foundation

/// `kiwishelf.*` — the shelf both bars sit on (#1517), read off
/// `KiwiShelfCommandSetting.parse`.
extension APIReference {
    static let kiwishelfRecords: [String: APIRecord] = [
        "set_edge": APIRecord(
            "Sets the screen edge the shelf occupies; it reserves "
                + "that edge in every layout.",
            .choice("edge", AppBarEdge.self)
        ),
        "set_alignment": APIRecord(
            "Places a bar along the edge while it is the only one "
                + "showing.",
            .choice("alignment", KiwiShelf.Alignment.self)
        ),
        "set_order": APIRecord(
            "Sets which bar takes the start of the edge while "
                + "both show; they sit at opposite ends.",
            .choice("order", KiwiShelf.Order.self)
        ),
        "set_share": APIRecord(
            "Sets the Space Bar's percentage of the edge (20–80) "
                + "once both bars overflow.",
            .number("percent")
        ),
        "set_thickness": APIRecord(
            "Sets the shelf's thickness in points, carved out of "
                + "the layout.",
            .number("thickness")
        ),
        "set_outer_margin": APIRecord(
            "Sets the shelf's distance from the screen border in "
                + "points; 0 is flush.",
            .number("margin")
        ),
        "set_inner_margin": APIRecord(
            "Adds points on the shelf's window side, on top of the "
                + "windows' outer gap.",
            .number("margin")
        ),
        "set_background_style": APIRecord(
            "Draws one plate behind the items, or a box per item.",
            .choice("style", KiwiShelf.BackgroundStyle.self)
        ),
        "set_liquid_glass": APIRecord(
            "Draws the plates and boxes in Liquid Glass "
                + "(macOS 26 and later).",
            .boolean("enabled")
        ),
        "set_background_fit": APIRecord(
            "Hugs each bar with its own plate, or spans one plate "
                + "along the edge.",
            .choice("fit", KiwiShelf.BackgroundFit.self)
        ),
        "set_corner_roundness": APIRecord(
            "Sets the corner rounding of plates and item boxes, "
                + "0–100 percent of half the thickness.",
            .number("percent")
        ),
        "set_item_gap": APIRecord(
            "Sets the spacing between items in points, both bars "
                + "alike.",
            .number("gap")
        ),
        "set_font_size": APIRecord(
            "Pins the font size in points for both bars; 0 scales "
                + "with thickness.",
            .number("size")
        ),
    ]
}
