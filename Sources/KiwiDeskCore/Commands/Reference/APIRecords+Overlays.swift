import Foundation

/// Overlay and single-setting command records (#1033).
/// `sticky.set_color` / `floating.set_color` also accept an
/// empty string, clearing the mark colour — that belongs in
/// the summary, not in a new argument kind.
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
        "set_liquid_glass": APIRecord(
            "Draws both drag visuals as macOS 26 Liquid Glass, "
                + "tinted by their fill colors.",
            .boolean("enabled")
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
        "set_sheen": APIRecord(
            "Lightens (to 1) or darkens (to -1) the top of the "
                + "border, highlight and drag borders; 0 is off.",
            .number("strength")
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
        "set_desktop_reach": APIRecord(
            "Carries sticky windows with each macOS Desktop switch "
                + "(needs the window-management bridge).",
            .boolean("enabled")
        ),
        "set_liquid_glass": APIRecord(
            "Draws the sticky mark as macOS 26 Liquid Glass, "
                + "tinted by its color.",
            .boolean("enabled")
        ),
    ]

    static let floatingRecords: [String: APIRecord] = [
        "set_mark": APIRecord(
            "Shows or hides the on-window mark on windows set "
                + "floating.",
            .boolean("enabled")
        ),
        "set_color": APIRecord(
            "Sets the floating mark and badge color; empty is "
                + "automatic.",
            .color("hex")
        ),
    ]

    static let mouseRecords: [String: APIRecord] = [
        "set_follows_focus": APIRecord(
            "Warps the mouse pointer to the center of the "
                + "focused window.",
            .boolean("enabled")
        ),
        "set_hover_focus": APIRecord(
            "Focuses and raises the window the mouse pointer comes "
                + "to rest on.",
            .boolean("enabled")
        ),
        "set_hover_focus_delay": APIRecord(
            "Sets how long the pointer rests before hover focus acts, "
                + "in milliseconds.",
            .integer("milliseconds")
        ),
    ]

    static let scrollGestureRecords: [String: APIRecord] = [
        "set_pan": APIRecord(
            "Sets the modifiers that move focus by scrolling, like "
                + "\"control+option\"; \"\" is off.",
            .text("modifiers")
        ),
        "set_space_step": APIRecord(
            "Sets the modifiers that step between Spaces by "
                + "scrolling; \"\" is off.",
            .text("modifiers")
        ),
        "set_long_swipes": APIRecord(
            "Lets a long trackpad swipe move one more window every "
                + "step distance of travel.",
            .boolean("enabled")
        ),
        "set_step_distance": APIRecord(
            "Sets the travel, in points, per extra window of a long "
                + "swipe.",
            .number("points")
        ),
        "set_natural_scrolling": APIRecord(
            "Makes a scroll gesture follow the fingers; an input, "
                + "trackpad or mouse, sets only that one.",
            .boolean("enabled"),
            .choice("input", ScrollInput.self, optional: true)
        ),
    ]

    static let quitRecords: [String: APIRecord] = [
        "set_layout": APIRecord(
            "Sets how windows are laid out when KiwiDesk quits.",
            .choice("layout", QuitLayoutStyle.self)
        ),
        "set_grid_target_depth": APIRecord(
            "Sets the quit grid's density target in windows per "
                + "cell.",
            .integer("depth")
        ),
    ]

    static let kiwivisionRecords: [String: APIRecord] = [
        "toggle": APIRecord(
            "Turns KiwiVision on or off; named, turns that lens on, "
                + "or off while it is on.",
            .text("lens", optional: true)
        ),
        "current": APIRecord(
            "Returns whether KiwiVision is on, the lens on, the settings "
                + "and every lens with its refusal."
        ),
        "define_lens": APIRecord(
            "Adds or replaces a lens: a Lua table, or a JSON object "
                + "string over the CLI.",
            .text("lens")
        ),
        "delete_lens": APIRecord(
            "Removes a lens for this session; KiwiVision turns off "
                + "if it was the one on.",
            .text("lens")
        ),
        "set_dim": APIRecord(
            "Sets how far KiwiVision dims, in percent (0-100).",
            .number("percent")
        ),
        "set_blur": APIRecord(
            "Blurs what KiwiVision dims; on by default.",
            .boolean("enabled")
        ),
        "set_appearance": APIRecord(
            "Sets the system appearance KiwiVision switches to "
                + "while on; unchanged by default.",
            .choice("appearance", VisionAppearance.self)
        ),
        "set_clear_wallpaper": APIRecord(
            "Leaves the wallpaper clear so KiwiVision dims only the "
                + "windows; off by default.",
            .boolean("enabled")
        ),
        "set_never_dimmed": APIRecord(
            "Replaces the never-dimmed apps: bundle ids or process "
                + "names, one or more; none clears it.",
            .text("app", optional: true)
        ),
        "set_clear_app": APIRecord(
            "Keeps every window of the focused app clear, not only "
                + "the focused one; off by default.",
            .boolean("enabled")
        ),
    ]

    static let kiwihubRecords: [String: APIRecord] = [
        "show": APIRecord(
            "Opens KiwiHub on a side, switches it there, or closes "
                + "it if that side is open.",
            .choice("side", KiwiHubSide.self)
        )
    ]
}
