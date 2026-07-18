import CoreGraphics
import Foundation

/// One parsed `space_bar.set_*` assignment (#293). Sibling of
/// `AppBarCommandSetting` with a single apply switch — the Space
/// Bar is global-only, so there is no override variant. Reuses
/// the App Bar's error type: the two parsers speak the same
/// vocabulary and their messages must not drift.
enum SpaceBarCommandSetting {
    case enabled(Bool)
    case edge(AppBarEdge)
    case alignment(SpaceBarStyle.Alignment)
    case thickness(CGFloat)
    case boxSize(CGFloat)
    case boxGap(CGFloat)
    case fontSize(CGFloat)
    case glyphCap(Int)
    case iconSource(BarAppIconSource)
    case tabBackground(SpaceBarStyle.TabBackground)
    case activeIndicator(SpaceBarStyle.ActiveIndicator)
    case cornerRoundness(CGFloat)
    case showFrontApp(Bool)
    case hideEmpty(Bool)
    case springDelay(Int)
    case textColor(String)
    case activeTextColor(String)
    case focusedItemColor(String)
    case hoverColor(String)
    case hoverTextColor(String)
    case boxColor(String)
    case activeBoxColor(String)
    case highlightColor(String)
    case backgroundColor(String)
    case groupBadgeColor(String)
    case groupBadgeTextColor(String)

    /// Parses a setter `field` (the command name minus
    /// `space_bar.set_`) and its args.
    static func parse(
        field: String,
        args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError> {
        if let keyword = boolFields[field] {
            guard let flag = args.first?.boolValue else {
                return .failure("expected boolean")
            }
            return .success(keyword(flag))
        }
        if field == "spring_delay" {
            return springDelay(args)
        }
        if field == "glyph_cap" {
            return glyphCap(args)
        }
        if let setting = parseChoice(field: field, args: args) {
            return setting
        }
        if let keyword = numberFields[field] {
            return number(args).map(keyword)
        }
        if let keyword = colorFields[field] {
            return color(args).map(keyword)
        }
        return .failure("unknown space bar setting: \(field)")
    }

    private static func parseChoice(
        field: String,
        args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError>? {
        switch field {
        case "edge":
            return choice(
                args,
                AppBarEdge.self,
                "top|bottom|left|right"
            ).map(Self.edge)
        case "alignment":
            return choice(
                args,
                SpaceBarStyle.Alignment.self,
                "start|center|end"
            ).map(Self.alignment)
        case "icon_source":
            return choice(
                args,
                BarAppIconSource.self,
                "app_image|app_font"
            ).map(Self.iconSource)
        case "tab_background":
            return choice(
                args,
                SpaceBarStyle.TabBackground.self,
                "boxed|plain"
            ).map(Self.tabBackground)
        case "active_indicator":
            return choice(
                args,
                SpaceBarStyle.ActiveIndicator.self,
                "ring|edge_mark|gap"
            ).map(Self.activeIndicator)
        default:
            return nil
        }
    }

    private static var boolFields: [String: (Bool) -> SpaceBarCommandSetting] {
        [
            "enabled": Self.enabled,
            "show_front_app": Self.showFrontApp,
            "hide_empty": Self.hideEmpty,
        ]
    }

    private static var numberFields:
        [String: (CGFloat) -> SpaceBarCommandSetting]
    {
        [
            "thickness": Self.thickness,
            "box_size": Self.boxSize,
            "box_gap": Self.boxGap,
            "font_size": Self.fontSize,
            "corner_roundness": Self.cornerRoundness,
        ]
    }

    private static var colorFields:
        [String: (String) -> SpaceBarCommandSetting]
    {
        [
            "text_color": Self.textColor,
            "active_text_color": Self.activeTextColor,
            "focused_item_color": Self.focusedItemColor,
            "hover_color": Self.hoverColor,
            "hover_text_color": Self.hoverTextColor,
            "box_color": Self.boxColor,
            "active_box_color": Self.activeBoxColor,
            "highlight_color": Self.highlightColor,
            "background_color": Self.backgroundColor,
            "group_badge_color": Self.groupBadgeColor,
            "group_badge_text_color": Self.groupBadgeTextColor,
        ]
    }

    /// Milliseconds, clamped to the Space Bar's valid dwell
    /// range — a stored out-of-range value can't spring instantly
    /// or hang.
    private static func springDelay(
        _ args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError> {
        guard let value = args.first?.numberValue else {
            return .failure("expected milliseconds")
        }
        let range = SpaceBarStyle.springDelayRange
        let clamped = min(
            max(Int(value), range.lowerBound),
            range.upperBound
        )
        return .success(.springDelay(clamped))
    }

    /// App-group glyph count, clamped to the Space Bar's valid
    /// cap range (#376) — a stored out-of-range value can't
    /// render an empty item or an unscannable row.
    private static func glyphCap(
        _ args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError> {
        guard let value = args.first?.numberValue,
            value.isFinite
        else {
            return .failure("expected a glyph count")
        }
        let range = SpaceBarStyle.glyphCapRange
        // Clamp as Double BEFORE Int(...) — `Int(1e300)` traps,
        // so a config typo would otherwise kill the WM (#58).
        let clamped = min(
            max(value.rounded(), Double(range.lowerBound)),
            Double(range.upperBound)
        )
        return .success(.glyphCap(Int(clamped)))
    }

    private static func number(
        _ args: [JSONValue]
    ) -> Result<CGFloat, AppBarSettingError> {
        guard let value = args.first?.numberValue else {
            return .failure("expected a length (pt)")
        }
        return .success(max(0, value))
    }

    private static func color(
        _ args: [JSONValue]
    ) -> Result<String, AppBarSettingError> {
        guard let hex = args.first?.stringValue,
            DragVisual.parseHex(hex) != nil
        else {
            return .failure("expected #RRGGBB or #RRGGBBAA")
        }
        return .success(hex)
    }

    private static func choice<T: RawRepresentable>(
        _ args: [JSONValue],
        _ type: T.Type,
        _ expected: String
    ) -> Result<T, AppBarSettingError>
    where T.RawValue == String {
        guard let raw = args.first?.stringValue,
            let value = T(rawValue: raw)
        else {
            return .failure("expected \(expected)")
        }
        return .success(value)
    }

    /// Writes the value into the global style — the only apply
    /// target (no per-layout mirror).
    func apply(to style: inout SpaceBarStyle) {
        switch self {
        case .enabled(let value): style.enabled = value
        case .edge(let value): style.edge = value
        case .alignment(let value): style.alignment = value
        case .thickness(let value): style.thickness = value
        case .boxSize(let value): style.boxSize = value
        case .boxGap(let value): style.boxGap = value
        case .fontSize(let value): style.fontSize = value
        case .glyphCap(let value): style.glyphCap = value
        case .iconSource(let value): style.iconSource = value
        case .tabBackground(let value):
            style.tabBackground = value
        case .activeIndicator(let value):
            style.activeIndicator = value
        case .cornerRoundness(let value):
            style.cornerRoundness = value
        case .showFrontApp(let value):
            style.showFrontApp = value
        case .hideEmpty(let value): style.hideEmpty = value
        case .springDelay(let value):
            style.springDelay = value
        case .textColor(let value): style.textColor = value
        case .activeTextColor(let value):
            style.activeTextColor = value
        case .focusedItemColor(let value):
            style.focusedItemColor = value
        case .hoverColor(let value): style.hoverColor = value
        case .hoverTextColor(let value):
            style.hoverTextColor = value
        case .boxColor(let value): style.boxColor = value
        case .activeBoxColor(let value):
            style.activeBoxColor = value
        case .highlightColor(let value):
            style.highlightColor = value
        case .backgroundColor(let value):
            style.backgroundColor = value
        case .groupBadgeColor(let value):
            style.groupBadgeColor = value
        case .groupBadgeTextColor(let value):
            style.groupBadgeTextColor = value
        }
    }
}
