import Foundation

/// Indicator-bar setters (global look + per-layout overrides),
/// the monocle/scroll orientation, and drag visuals — the
/// widest config surfaces.
extension LuaConfigWriter {
    /// The global `app_bar.set_*` look every layout's bar inherits.
    static func appBarStyle(_ style: AppBarStyle) -> String {
        [
            call("position", str(style.position.rawValue)),
            call("thickness", num(style.thickness)),
            call("style", str(style.style.rawValue)),
            call("active_style", str(style.activeStyle.rawValue)),
            call("item_size", num(style.itemSize)),
            call("item_gap", num(style.itemGap)),
            call("content", str(style.content.rawValue)),
            call(
                "group_adjacent_windows",
                LuaLiteral.bool(style.groupAdjacentWindows)
            ),
            call("font_size", num(style.fontSize)),
            call("corner_radius", num(style.cornerRadius)),
            call("text_color", str(style.textColor)),
            call("box_color", str(style.boxColor)),
            call("active_text_color", str(style.activeTextColor)),
            call("active_box_color", str(style.activeBoxColor)),
            call("highlight_color", str(style.highlightColor)),
            call("hover_color", str(style.hoverColor)),
            call("hover_text_color", str(style.hoverTextColor)),
            call("background_color", str(style.backgroundColor)),
            call("group_badge_color", str(style.groupBadgeColor)),
            call(
                "group_badge_text_color",
                str(style.groupBadgeTextColor)
            ),
        ].joined(separator: "\n")
    }

    private static func call(
        _ field: String,
        _ value: String
    ) -> String {
        "app_bar.set_\(field)(" + value + ")"
    }

    private static func num(_ value: CGFloat) -> String {
        LuaLiteral.number(value)
    }

    private static func str(_ value: String) -> String {
        LuaLiteral.string(value)
    }

    /// A layout's own bar: its `enabled` toggle plus only the
    /// fields it actually overrides (inherited fields stay
    /// absent so they keep tracking the global style).
    static func layoutBar(
        _ prefix: String,
        _ bar: LayoutAppBar
    ) -> String {
        var lines = [
            "\(prefix).set_app_bar_enabled("
                + LuaLiteral.bool(bar.enabled) + ")"
        ]
        func add(_ field: String, _ value: String?) {
            guard let value else { return }
            lines.append(
                "\(prefix).set_app_bar_\(field)(" + value + ")"
            )
        }
        add("position", bar.position.map { str($0.rawValue) })
        add("thickness", bar.thickness.map(num))
        add("style", bar.style.map { str($0.rawValue) })
        add(
            "active_style",
            bar.activeStyle.map { str($0.rawValue) }
        )
        add("item_size", bar.itemSize.map(num))
        add("item_gap", bar.itemGap.map(num))
        add("content", bar.content.map { str($0.rawValue) })
        add(
            "group_adjacent_windows",
            bar.groupAdjacentWindows.map { LuaLiteral.bool($0) }
        )
        add("font_size", bar.fontSize.map(num))
        add("corner_radius", bar.cornerRadius.map(num))
        addColors(&lines, prefix: prefix, bar: bar)
        return lines.joined(separator: "\n")
    }

    private static func addColors(
        _ lines: inout [String],
        prefix: String,
        bar: LayoutAppBar
    ) {
        let colors: [(String, String?)] = [
            ("text_color", bar.textColor),
            ("box_color", bar.boxColor),
            ("active_text_color", bar.activeTextColor),
            ("active_box_color", bar.activeBoxColor),
            ("highlight_color", bar.highlightColor),
            ("hover_color", bar.hoverColor),
            ("hover_text_color", bar.hoverTextColor),
            ("background_color", bar.backgroundColor),
            ("group_badge_color", bar.groupBadgeColor),
            ("group_badge_text_color", bar.groupBadgeTextColor),
        ]
        for (field, value) in colors {
            guard let value else { continue }
            lines.append(
                "\(prefix).set_app_bar_\(field)(" + str(value) + ")"
            )
        }
    }

    /// monocle.* — orientation plus its bar overrides.
    static func monocle(_ params: MonocleParams) -> String {
        [
            "monocle.set_orientation("
                + str(params.orientation.rawValue) + ")",
            layoutBar("monocle", params.appBar),
        ].joined(separator: "\n")
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
