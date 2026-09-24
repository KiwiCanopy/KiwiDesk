import CoreGraphics
import Foundation

/// Parsed `space_bar.set_*` command setting representation
/// (#293). Reuses the App Bar's error type: the two parsers speak
/// one vocabulary and their messages must not drift.
enum SpaceBarCommandSetting {
    case enabled(Bool)
    case glyphCap(Int)
    case frontAppTitleCap(Int)
    case activeIndicator(SpaceBarStyle.ActiveIndicator)
    case activeDimFactor(CGFloat)
    case showFrontApp(Bool)
    case hideEmpty(Bool)
    case stickyBadge(Bool)
    case springDelay(Int)
    case focusedItemColor(String)

    /// Parses a setter field and its arguments into SpaceBarCommandSetting.
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
        if field == "front_app_title_cap" {
            return frontAppTitleCap(args)
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
        case "active_indicator":
            return BarSettingChoice.value(
                args,
                SpaceBarStyle.ActiveIndicator.self
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
            "sticky_badge": Self.stickyBadge,
        ]
    }

    private static var numberFields:
        [String: (CGFloat) -> SpaceBarCommandSetting]
    {
        [
            "active_dim_factor": Self.activeDimFactor
        ]
    }

    /// Color setting field constructors by wire key. Internal, not
    /// private: the palette shelf (#375) routes through these same
    /// validated setters; see the AppBar twin.
    static var colorFields: [String: (String) -> SpaceBarCommandSetting] {
        [
            "focused_item_color": Self.focusedItemColor
        ]
    }

    /// Parses dwell spring delay in milliseconds (#58, #386).
    private static func springDelay(
        _ args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError> {
        guard let value = args.first?.numberValue,
            value.isFinite
        else {
            return .failure("expected milliseconds")
        }
        let range = SpaceBarStyle.springDelayRange
        // Clamp as Double BEFORE Int(...) — `Int(1e300)` traps, so
        // a config typo would kill the WM (#58/#386).
        let clamped = min(
            max(value.rounded(), Double(range.lowerBound)),
            Double(range.upperBound)
        )
        return .success(.springDelay(Int(clamped)))
    }

    /// Parses the front-app title length in characters (#58).
    private static func frontAppTitleCap(
        _ args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError> {
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
        return .success(.frontAppTitleCap(Int(clamped)))
    }

    /// Parses app glyph count cap (#58, #376).
    private static func glyphCap(
        _ args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError> {
        guard let value = args.first?.numberValue,
            value.isFinite
        else {
            return .failure("expected a glyph count")
        }
        let range = SpaceBarStyle.glyphCapRange
        // Clamp as Double BEFORE Int(...) — `Int(1e300)` traps
        // (#58).
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

    /// Applies setting value to SpaceBarStyle.
    func apply(to style: inout SpaceBarStyle) {
        switch self {
        case .enabled(let value): style.enabled = value
        case .glyphCap(let value): style.glyphCap = value
        case .frontAppTitleCap(let value):
            style.frontAppTitleCap = value
        case .activeIndicator(let value):
            style.activeIndicator = value
        case .activeDimFactor(let value):
            style.activeDimFactor = AppBarStyle.clampDim(value)
        case .showFrontApp(let value):
            style.showFrontApp = value
        case .hideEmpty(let value): style.hideEmpty = value
        case .stickyBadge(let value): style.stickyBadge = value
        case .springDelay(let value):
            style.springDelay = value
        case .focusedItemColor(let value):
            style.focusedItemColor = value
        }
    }
}
