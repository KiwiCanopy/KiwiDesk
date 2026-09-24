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
        "kiwishelf.fill_color",
        "kiwishelf.item_color",
        "kiwishelf.active_item_color",
        "kiwishelf.highlight_color",
        "border.focused_color",
        "drag.ghost.fill_color",
        "drag.ghost.border_color",
    ]

    /// The fifteen roles drawn by the detail panel (#231).
    static let panel: Set<String> = [
        // The shelf: plate, the accent ladder, the badge pair,
        // and the Space Bar's own focused-window ink (#1517).
        "kiwishelf.fill_color",
        "kiwishelf.item_color",
        "kiwishelf.active_item_color",
        "kiwishelf.highlight_color",
        "kiwishelf.group_badge_color",
        "kiwishelf.group_badge_text_color",
        "space_bar.focused_item_color",
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
        "kiwishelf.hover_fill_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
        "kiwishelf.hover_item_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
    ]

    static func drawn(at scale: PaletteSceneScale) -> Set<String> {
        switch scale {
        case .tile: return tile
        case .panel: return panel
        }
    }
}
