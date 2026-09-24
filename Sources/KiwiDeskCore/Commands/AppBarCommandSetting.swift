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
    case groupAdjacentWindows(Bool)

    /// Parses setter field name and arguments.
    static func parse(
        field: String,
        args: [JSONValue]
    ) -> Result<AppBarCommandSetting, AppBarSettingError> {
        if let setting = parseChoice(field: field, args: args) {
            return setting
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
        case "group_adjacent_windows":
            guard let flag = args.first?.boolValue else {
                return .failure("expected boolean")
            }
            return .success(.groupAdjacentWindows(flag))
        default:
            return nil
        }
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
        case .groupAdjacentWindows(let value):
            style.groupAdjacentWindows = value
        }
    }

    /// Writes the value into a layout's bar as an override.
    func apply(to bar: inout LayoutAppBar) {
        switch self {
        case .activeIndicator(let value):
            bar.activeIndicator = value
        case .content(let value): bar.content = value
        case .titleCap(let value): bar.titleCap = value
        case .groupAdjacentWindows(let value):
            bar.groupAdjacentWindows = value
        }
    }
}
