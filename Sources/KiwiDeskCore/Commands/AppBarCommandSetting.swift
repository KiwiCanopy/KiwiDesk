import CoreGraphics
import Foundation

/// Bar setting error with user-facing message.
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

/// Parsed App Bar command setting representation.
enum AppBarCommandSetting {
    case activeIndicator(AppBarStyle.ActiveIndicator)
    case content(AppBarStyle.Content)
    case titleCap(Int)
    case iconSource(BarAppIconSource)
    case groupAdjacentWindows(Bool)
    case dimFactor(CGFloat)
    case itemColor(String)
    case fillColor(String)
    case activeItemColor(String)
    case highlightColor(String)
    case hoverFillColor(String)
    case hoverItemColor(String)
    case groupBadgeColor(String)
    case groupBadgeTextColor(String)

    /// Parses setter field name and arguments.
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
        case "active_indicator":
            return BarSettingChoice.value(
                args,
                AppBarStyle.ActiveIndicator.self
            ).map(Self.activeIndicator)
        case "content":
            return BarSettingChoice.value(
                args,
                AppBarStyle.Content.self
            ).map(Self.content)
        case "title_cap":
            return titleCap(args)
        case "icon_source":
            return BarSettingChoice.value(
                args,
                BarAppIconSource.self
            ).map(Self.iconSource)
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
            "dim_factor": Self.dimFactor
        ]
    }

    /// Color setting field constructors by wire key. Internal, not
    /// private: the palette shelf (#375) routes through these same
    /// validated setters.
    static var colorFields: [String: (String) -> AppBarCommandSetting] {
        [
            "item_color": Self.itemColor,
            "fill_color": Self.fillColor,
            "active_item_color": Self.activeItemColor,
            "highlight_color": Self.highlightColor,
            "hover_fill_color": Self.hoverFillColor,
            "hover_item_color": Self.hoverItemColor,
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

    /// Parses title character cap. Mirrors the SpaceBar twin,
    /// including clamp-as-Double BEFORE `Int(...)` — `Int(1e300)`
    /// traps, so a config typo would kill the WM (#58).
    private static func titleCap(
        _ args: [JSONValue]
    ) -> Result<AppBarCommandSetting, AppBarSettingError> {
        guard let value = args.first?.numberValue,
            value.isFinite
        else {
            return .failure("expected a character count")
        }
        let range = AppBarStyle.titleCapRange
        let clamped = min(
            max(value.rounded(), Double(range.lowerBound)),
            Double(range.upperBound)
        )
        return .success(.titleCap(Int(clamped)))
    }

    /// Applies concrete setting to AppBarStyle.
    func apply(to style: inout AppBarStyle) {
        switch self {
        case .activeIndicator(let value):
            style.activeIndicator = value
        case .content(let value): style.content = value
        case .titleCap(let value): style.titleCap = value
        case .iconSource(let value): style.iconSource = value
        case .groupAdjacentWindows(let value):
            style.groupAdjacentWindows = value
        case .dimFactor(let value):
            style.dimFactor = AppBarStyle.clampDim(value)
        case .itemColor(let value): style.itemColor = value
        case .fillColor(let value): style.fillColor = value
        case .activeItemColor(let value):
            style.activeItemColor = value
        case .highlightColor(let value):
            style.highlightColor = value
        case .hoverFillColor(let value): style.hoverFillColor = value
        case .hoverItemColor(let value):
            style.hoverItemColor = value
        case .groupBadgeColor(let value):
            style.groupBadgeColor = value
        case .groupBadgeTextColor(let value):
            style.groupBadgeTextColor = value
        }
    }

    /// Writes the value into a layout's bar as an override.
    func apply(to bar: inout LayoutAppBar) {
        switch self {
        case .activeIndicator(let value):
            bar.activeIndicator = value
        case .content(let value): bar.content = value
        case .titleCap(let value): bar.titleCap = value
        case .iconSource(let value): bar.iconSource = value
        case .groupAdjacentWindows(let value):
            bar.groupAdjacentWindows = value
        case .dimFactor(let value):
            bar.dimFactor = AppBarStyle.clampDim(value)
        case .itemColor(let value): bar.itemColor = value
        case .fillColor(let value): bar.fillColor = value
        case .activeItemColor(let value):
            bar.activeItemColor = value
        case .highlightColor(let value):
            bar.highlightColor = value
        case .hoverFillColor(let value): bar.hoverFillColor = value
        case .hoverItemColor(let value):
            bar.hoverItemColor = value
        case .groupBadgeColor(let value):
            bar.groupBadgeColor = value
        case .groupBadgeTextColor(let value):
            bar.groupBadgeTextColor = value
        }
    }
}
