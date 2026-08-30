import KiwiDeskCore

/// Display scale for palette scene drawings (#753, #793, `SchematicScale`).
enum PaletteSceneScale {
    /// The palette shelf's 72 pt tile: composition at a glance.
    case tile
    /// The detail panel: all visible roles drawn simultaneously.
    case panel
}

/// Census of drawn and withheld palette roles (`PaletteSceneRoleTests`,
/// `ColorPaletteKeys.all`).
enum PaletteSceneRoles {
    /// The seven roles drawn by the shelf tile.
    static let tile: Set<String> = [
        "app_bar.fill_color",
        "app_bar.item_color",
        "app_bar.active_item_color",
        "app_bar.highlight_color",
        "border.focused_color",
        "drag.ghost.fill_color",
        "drag.ghost.border_color",
    ]

    /// The twenty-one roles drawn by the detail panel (#231).
    static let panel: Set<String> = [
        // Space Bar: plate, the accent ladder, the badge pair.
        "space_bar.fill_color",
        "space_bar.item_color",
        "space_bar.active_item_color",
        "space_bar.focused_item_color",
        "space_bar.highlight_color",
        "space_bar.group_badge_color",
        "space_bar.group_badge_text_color",
        // App Bar: the same shape, one accent step shorter.
        "app_bar.fill_color",
        "app_bar.item_color",
        "app_bar.active_item_color",
        "app_bar.highlight_color",
        "app_bar.group_badge_color",
        "app_bar.group_badge_text_color",
        // Border focus pair.
        "border.focused_color",
        "border.unfocused_color",
        // State marks.
        "sticky.color",
        "floating.color",
        // Drag visuals twinned (#231).
        "drag.ghost.fill_color",
        "drag.ghost.border_color",
        "drag.drop_zone.fill_color",
        "drag.drop_zone.border_color",
    ]

    /// Roles withheld from still frame rendering (#708).
    static let withheld: [String: String] = [
        "app_bar.hover_fill_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
        "app_bar.hover_item_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
        "space_bar.hover_fill_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
        "space_bar.hover_item_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
    ]

    static func drawn(at scale: PaletteSceneScale) -> Set<String> {
        switch scale {
        case .tile: return tile
        case .panel: return panel
        }
    }
}
