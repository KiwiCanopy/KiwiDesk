import Foundation

/// Monocle bar and drag-visual setters (the widest surfaces).
extension LuaConfigWriter {
    static func monocle(_ params: MonocleParams) -> String {
        let bar = params.bar
        return [
            "monocle.set_orientation("
                + LuaLiteral.string(params.orientation.rawValue)
                + ")",
            "monocle.set_bar_enabled("
                + LuaLiteral.bool(bar.enabled) + ")",
            "monocle.set_bar_position("
                + LuaLiteral.string(bar.position.rawValue) + ")",
            "monocle.set_bar_thickness("
                + LuaLiteral.number(bar.thickness) + ")",
            "monocle.set_bar_style("
                + LuaLiteral.string(bar.style.rawValue) + ")",
            "monocle.set_bar_active_style("
                + LuaLiteral.string(bar.activeStyle.rawValue)
                + ")",
            "monocle.set_bar_item_size("
                + LuaLiteral.number(bar.itemSize) + ")",
            "monocle.set_bar_item_gap("
                + LuaLiteral.number(bar.itemGap) + ")",
            "monocle.set_bar_content("
                + LuaLiteral.string(bar.content.rawValue) + ")",
            "monocle.set_bar_font_size("
                + LuaLiteral.number(bar.fontSize) + ")",
            "monocle.set_bar_corner_radius("
                + LuaLiteral.number(bar.cornerRadius) + ")",
            "monocle.set_bar_group_adjacent_windows("
                + LuaLiteral.bool(bar.groupAdjacentWindows) + ")",
            monocleColors(bar),
        ].joined(separator: "\n")
    }

    private static func monocleColors(
        _ bar: MonocleBarParams
    ) -> String {
        [
            colorCall("set_bar_text_color", bar.textColor),
            colorCall("set_bar_box_color", bar.boxColor),
            colorCall(
                "set_bar_active_text_color",
                bar.activeTextColor
            ),
            colorCall(
                "set_bar_active_box_color",
                bar.activeBoxColor
            ),
            colorCall(
                "set_bar_highlight_color",
                bar.highlightColor
            ),
            colorCall("set_bar_hover_color", bar.hoverColor),
            colorCall(
                "set_bar_hover_text_color",
                bar.hoverTextColor
            ),
            colorCall(
                "set_bar_background_color",
                bar.backgroundColor
            ),
            colorCall(
                "set_bar_group_badge_color",
                bar.groupBadgeColor
            ),
            colorCall(
                "set_bar_group_badge_text_color",
                bar.groupBadgeTextColor
            ),
        ].joined(separator: "\n")
    }

    private static func colorCall(
        _ name: String,
        _ hex: String
    ) -> String {
        "monocle.\(name)(" + LuaLiteral.string(hex) + ")"
    }

    // MARK: - Drag visuals

    static func dragVisuals(
        _ settings: TilingSettings
    ) -> String {
        [
            dragVisual("ghost", settings.dragGhost),
            dragVisual("drop_zone", settings.dragDropZone),
            "drag.set_corner_radius("
                + LuaLiteral.number(settings.dragCornerRadius)
                + ")",
        ].joined(separator: "\n")
    }

    private static func dragVisual(
        _ prefix: String,
        _ visual: DragVisual
    ) -> String {
        [
            "drag.set_\(prefix)_enabled("
                + LuaLiteral.bool(visual.enabled) + ")",
            "drag.set_\(prefix)_border("
                + LuaLiteral.bool(visual.border) + ")",
            "drag.set_\(prefix)_border_thickness("
                + LuaLiteral.number(visual.borderThickness)
                + ")",
            "drag.set_\(prefix)_border_alignment("
                + LuaLiteral.string(
                    visual.borderAlignment.rawValue
                ) + ")",
            "drag.set_\(prefix)_border_color("
                + LuaLiteral.string(visual.borderColor) + ")",
            "drag.set_\(prefix)_fill("
                + LuaLiteral.bool(visual.fill) + ")",
            "drag.set_\(prefix)_fill_color("
                + LuaLiteral.string(visual.fillColor) + ")",
        ].joined(separator: "\n")
    }
}
