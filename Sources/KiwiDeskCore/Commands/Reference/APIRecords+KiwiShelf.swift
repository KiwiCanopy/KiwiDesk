import Foundation

/// `kiwishelf.*` — the shelf both bars sit on (#1517), read off
/// `KiwiShelfCommandSetting.parse`.
extension APIReference {
    static let kiwishelfRecords: [String: APIRecord] = [
        "set_edge": APIRecord(
            "Sets the screen edge the shelf occupies; it reserves "
                + "that edge wherever a bar draws.",
            .choice("edge", AppBarEdge.self)
        ),
        "set_alignment": APIRecord(
            "Places the plate along the edge — one bar, or both as "
                + "one joined plate.",
            .choice("alignment", KiwiShelf.Alignment.self)
        ),
        "set_order": APIRecord(
            "Sets which bar's section comes first while both "
                + "show on the joined plate.",
            .choice("order", KiwiShelf.Order.self)
        ),
        "set_minimum": APIRecord(
            "Sets the percentage of the edge (20–80) the Space Bar "
                + "keeps once the shelf is full.",
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
        "set_highlight_width": APIRecord(
            "Sets the active indicator's width in points, 1–6; "
                + "the edge mark scales with it.",
            .number("width")
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
        "set_icon_source": APIRecord(
            "Sets whether both bars draw app icons from the app "
                + "image or the bundled glyph font.",
            .choice("source", BarAppIconSource.self)
        ),
        "set_dim_factor": APIRecord(
            "Sets the opacity of untinted idle content — emoji "
                + "and app images — on both bars.",
            .number("factor")
        ),
        "set_item_color": APIRecord(
            "Sets the text and glyph color of items; an idle "
                + "Space identifier draws it dimmed.",
            .color("hex")
        ),
        "set_active_item_color": APIRecord(
            "Sets the text and glyph color of the active item.",
            .color("hex")
        ),
        "set_highlight_color": APIRecord(
            "Sets the color of both bars' active indicator.",
            .color("hex")
        ),
        "set_hover_fill_color": APIRecord(
            "Sets the hover fill on non-active items.",
            .color("hex")
        ),
        "set_hover_item_color": APIRecord(
            "Sets the text and glyph color of hovered items.",
            .color("hex")
        ),
        "set_fill_color": APIRecord(
            "Sets the plate's one fill, or the glass tint.",
            .color("hex")
        ),
        "set_group_badge_color": APIRecord(
            "Sets the background color of count and overflow "
                + "badges.",
            .color("hex")
        ),
        "set_group_badge_text_color": APIRecord(
            "Sets the text color of count and overflow badges.",
            .color("hex")
        ),
    ]
}
