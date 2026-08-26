import Foundation

/// `drag.*`, `border.*`, `sticky.*`, `floating.*`, `mouse.*`
/// and `quit.*` — the overlays and the odd single-setting
/// namespaces (#1033).
///
/// The colour setters take `.color`; `sticky.set_color` and
/// `floating.set_color` also accept an empty string, which
/// clears the mark colour back to the palette's — that belongs
/// in the summary, not in a new argument kind.
extension APIReference {
    static let dragRecords: [String: APIRecord] = [
        "set_ghost_enabled": APIRecord(
            "Shows or hides the ghost visual.",
            .boolean("enabled")
        ),
        "set_ghost_border": APIRecord(
            "Enables or disables the border on the ghost visual.",
            .boolean("enabled")
        ),
        "set_ghost_border_width": APIRecord(
            "Sets the border width of the ghost visual in points.",
            .number("width")
        ),
        "set_ghost_border_alignment": APIRecord(
            "Positions the ghost border inside or outside the "
                + "slot.",
            .choice("alignment", BorderAlignment.self)
        ),
        "set_ghost_border_color": APIRecord(
            "Sets the border color of the ghost visual.",
            .color("hex")
        ),
        "set_ghost_fill": APIRecord(
            "Enables or disables the fill on the ghost visual.",
            .boolean("enabled")
        ),
        "set_ghost_fill_color": APIRecord(
            "Sets the fill color of the ghost visual.",
            .color("hex")
        ),
        "set_drop_zone_enabled": APIRecord(
            "Shows or hides the drop zone visual.",
            .boolean("enabled")
        ),
        "set_drop_zone_border": APIRecord(
            "Enables or disables the border on the drop zone "
                + "visual.",
            .boolean("enabled")
        ),
        "set_drop_zone_border_width": APIRecord(
            "Sets the border width of the drop zone visual in "
                + "points.",
            .number("width")
        ),
        "set_drop_zone_border_alignment": APIRecord(
            "Positions the drop zone border inside or outside the "
                + "slot.",
            .choice("alignment", BorderAlignment.self)
        ),
        "set_drop_zone_border_color": APIRecord(
            "Sets the border color of the drop zone visual.",
            .color("hex")
        ),
        "set_drop_zone_fill": APIRecord(
            "Enables or disables the fill on the drop zone "
                + "visual.",
            .boolean("enabled")
        ),
        "set_drop_zone_fill_color": APIRecord(
            "Sets the fill color of the drop zone visual.",
            .color("hex")
        ),
        "set_corner_radius": APIRecord(
            "Sets the corner rounding of both drag visuals in "
                + "points.",
            .number("radius")
        ),
    ]

    static let borderRecords: [String: APIRecord] = [
        "set_enabled": APIRecord(
            "Turns the focus border on or off.",
            .boolean("enabled")
        ),
        "set_width": APIRecord(
            "Sets the focus border width in points.",
            .number("width")
        ),
        "set_focused_color": APIRecord(
            "Sets the focused window's border color.",
            .color("hex")
        ),
        "set_unfocused_enabled": APIRecord(
            "Draws a border on unfocused windows too.",
            .boolean("enabled")
        ),
        "set_unfocused_color": APIRecord(
            "Sets the unfocused windows' border color.",
            .color("hex")
        ),
        "set_corner_style": APIRecord(
            "Sets whether border corners are rounded or square.",
            .choice("style", BorderStyle.CornerStyle.self)
        ),
        "set_glow": APIRecord(
            "Wraps the focused border in a soft colored bloom.",
            .boolean("enabled")
        ),
        "set_glow_size": APIRecord(
            "Sets the glow blur radius in points; 0 is "
                + "automatic.",
            .number("size")
        ),
        "set_draw_order": APIRecord(
            "Sets whether the border stacks behind or in front of "
                + "windows.",
            .choice("order", BorderStyle.DrawOrder.self)
        ),
        "fit_gaps": APIRecord(
            "Sizes layout gaps to clear the border, plus "
                + "optional whitespace.",
            .number("remaining", optional: true)
        ),
    ]

    static let stickyRecords: [String: APIRecord] = [
        "set_mark": APIRecord(
            "Shows or hides the on-window sticky mark.",
            .boolean("enabled")
        ),
        "set_color": APIRecord(
            "Sets the sticky mark's color; an empty string is "
                + "automatic.",
            .color("hex")
        ),
    ]

    static let floatingRecords: [String: APIRecord] = [
        "set_color": APIRecord(
            "Sets the Space Bar floating badge color; empty is "
                + "automatic.",
            .color("hex")
        )
    ]

    static let mouseRecords: [String: APIRecord] = [
        "set_follows_focus": APIRecord(
            "Warps the mouse pointer to the center of the "
                + "focused window.",
            .boolean("enabled")
        )
    ]

    static let quitRecords: [String: APIRecord] = [
        "set_layout": APIRecord(
            "Sets how windows are gathered when KiwiDesk quits.",
            .choice("layout", QuitLayoutStyle.self)
        ),
        "set_grid_target_depth": APIRecord(
            "Sets the quit grid's density target in windows per "
                + "cell.",
            .integer("depth")
        ),
    ]
}
