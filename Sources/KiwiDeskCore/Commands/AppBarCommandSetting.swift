import CoreGraphics
import Foundation

/// A bar-setter parse failure, carrying the message shown to the
/// user. String-literal-expressible so parsers can just write
/// `.failure("expected boolean")`.
struct AppBarSettingError: Error, Equatable,
    ExpressibleByStringInterpolation
{
    let message: String
    init(stringLiteral value: String) { message = value }
    init(
        stringInterpolation: DefaultStringInterpolation
    ) {
        message = String(
            stringInterpolation: stringInterpolation
        )
    }
}

/// One parsed bar assignment. Parsing (and its validation) lives
/// here once; applying it targets either the global `AppBarStyle`
/// (concrete, via `app_bar.set_*`) or a layout's `LayoutAppBar` (as an
/// override, via `monocle.set_app_bar_*` / `scroll.set_app_bar_*`).
enum AppBarCommandSetting {
    case position(AppBarStyle.Position)
    case thickness(CGFloat)
    case tabBackground(AppBarStyle.TabBackground)
    case activeIndicator(AppBarStyle.ActiveIndicator)
    case itemSize(CGFloat)
    case itemGap(CGFloat)
    case content(AppBarStyle.Content)
    case groupAdjacentWindows(Bool)
    case fontSize(CGFloat)
    case cornerRoundness(CGFloat)
    case textColor(String)
    case boxColor(String)
    case activeTextColor(String)
    case activeBoxColor(String)
    case highlightColor(String)
    case hoverColor(String)
    case hoverTextColor(String)
    case backgroundColor(String)
    case groupBadgeColor(String)
    case groupBadgeTextColor(String)

    /// Parses a setter `field` — the command name minus its
    /// prefix (`thickness`, `active_style`, `text_color`, …) —
    /// and its args. `.failure` carries the error message.
    static func parse(
        field: String,
        args: [JSONValue]
    ) -> Result<AppBarCommandSetting, AppBarSettingError> {
        if let setting = parseChoice(field: field, args: args) {
            return setting
        }
        if let keyword = numberFields[field] {
            return number(args).map(keyword)
        }
        if let keyword = colorFields[field] {
            return color(args).map(keyword)
        }
        return .failure("unknown bar setting: \(field)")
    }

    /// Enum- and bool-valued fields.
    private static func parseChoice(
        field: String,
        args: [JSONValue]
    ) -> Result<AppBarCommandSetting, AppBarSettingError>? {
        switch field {
        case "position":
            return choice(
                args,
                AppBarStyle.Position.self,
                "start|end"
            ).map(Self.position)
        case "tab_background":
            return choice(
                args,
                AppBarStyle.TabBackground.self,
                "boxed|plain"
            ).map(Self.tabBackground)
        case "active_indicator":
            return choice(
                args,
                AppBarStyle.ActiveIndicator.self,
                "ring|edge_mark|gap"
            ).map(Self.activeIndicator)
        case "content":
            return choice(
                args,
                AppBarStyle.Content.self,
                "icon|name|icon_and_name"
            ).map(Self.content)
        case "group_adjacent_windows":
            guard let flag = args.first?.boolValue else {
                return .failure("expected boolean")
            }
            return .success(.groupAdjacentWindows(flag))
        default:
            return nil
        }
    }

    private static var numberFields:
        [String: (CGFloat) -> AppBarCommandSetting]
    {
        [
            "thickness": Self.thickness,
            "item_size": Self.itemSize,
            "item_gap": Self.itemGap,
            "font_size": Self.fontSize,
            "corner_roundness": Self.cornerRoundness,
        ]
    }

    private static var colorFields: [String: (String) -> AppBarCommandSetting]
    {
        [
            "text_color": Self.textColor,
            "box_color": Self.boxColor,
            "active_text_color": Self.activeTextColor,
            "active_box_color": Self.activeBoxColor,
            "highlight_color": Self.highlightColor,
            "hover_color": Self.hoverColor,
            "hover_text_color": Self.hoverTextColor,
            "background_color": Self.backgroundColor,
            "group_badge_color": Self.groupBadgeColor,
            "group_badge_text_color": Self.groupBadgeTextColor,
        ]
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
    ) -> Result<T, AppBarSettingError> where T.RawValue == String {
        guard let raw = args.first?.stringValue,
            let value = T(rawValue: raw)
        else {
            return .failure("expected \(expected)")
        }
        return .success(value)
    }

    /// Writes the value into the global style (concrete).
    func apply(to style: inout AppBarStyle) {
        switch self {
        case .position(let value): style.position = value
        case .thickness(let value): style.thickness = value
        case .tabBackground(let value):
            style.tabBackground = value
        case .activeIndicator(let value):
            style.activeIndicator = value
        case .itemSize(let value): style.itemSize = value
        case .itemGap(let value): style.itemGap = value
        case .content(let value): style.content = value
        case .groupAdjacentWindows(let value):
            style.groupAdjacentWindows = value
        case .fontSize(let value): style.fontSize = value
        case .cornerRoundness(let value):
            style.cornerRoundness = value
        case .textColor(let value): style.textColor = value
        case .boxColor(let value): style.boxColor = value
        case .activeTextColor(let value):
            style.activeTextColor = value
        case .activeBoxColor(let value):
            style.activeBoxColor = value
        case .highlightColor(let value):
            style.highlightColor = value
        case .hoverColor(let value): style.hoverColor = value
        case .hoverTextColor(let value):
            style.hoverTextColor = value
        case .backgroundColor(let value):
            style.backgroundColor = value
        case .groupBadgeColor(let value):
            style.groupBadgeColor = value
        case .groupBadgeTextColor(let value):
            style.groupBadgeTextColor = value
        }
    }

    /// Writes the value into a layout's bar as an override.
    func apply(to bar: inout LayoutAppBar) {
        switch self {
        case .position(let value): bar.position = value
        case .thickness(let value): bar.thickness = value
        case .tabBackground(let value): bar.tabBackground = value
        case .activeIndicator(let value):
            bar.activeIndicator = value
        case .itemSize(let value): bar.itemSize = value
        case .itemGap(let value): bar.itemGap = value
        case .content(let value): bar.content = value
        case .groupAdjacentWindows(let value):
            bar.groupAdjacentWindows = value
        case .fontSize(let value): bar.fontSize = value
        case .cornerRoundness(let value):
            bar.cornerRoundness = value
        case .textColor(let value): bar.textColor = value
        case .boxColor(let value): bar.boxColor = value
        case .activeTextColor(let value):
            bar.activeTextColor = value
        case .activeBoxColor(let value):
            bar.activeBoxColor = value
        case .highlightColor(let value):
            bar.highlightColor = value
        case .hoverColor(let value): bar.hoverColor = value
        case .hoverTextColor(let value):
            bar.hoverTextColor = value
        case .backgroundColor(let value):
            bar.backgroundColor = value
        case .groupBadgeColor(let value):
            bar.groupBadgeColor = value
        case .groupBadgeTextColor(let value):
            bar.groupBadgeTextColor = value
        }
    }
}
