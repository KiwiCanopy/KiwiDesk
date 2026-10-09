import CoreGraphics
import Foundation

/// Parsed `space_bar.set_*` command setting representation
/// (#293). Reuses the App Bar's error type: the two parsers speak
/// one vocabulary and their messages must not drift.
enum SpaceBarCommandSetting {
    case enabled(Bool)
    case reserve(Bool)
    case edge(AppBarEdge)
    /// `set_edge(edge, screen)` — one screen's edge (#1948), the
    /// screen resolved to its fingerprint and judged over `among`,
    /// which the parse leaves empty and `KiwiCore` fills with its
    /// `screenEdgeScope` (`scoped(to:)`) before it applies.
    case screenEdge(AppBarEdge, screen: String, among: Set<String>)
    case glyphSpan(Int)
    case glyphGap(CGFloat)
    case groupAdjacentWindows(Bool)
    case inactiveContent(SpaceBarStyle.InactiveContent)
    case itemLabel(SpaceBarStyle.ItemLabel)
    case frontAppTitleCap(Int)
    case activeIndicator(SpaceBarStyle.ActiveIndicator)
    case activeDimFactor(CGFloat)
    case showFrontApp(Bool)
    case hideEmpty(Bool)
    case stickyBadge(Bool)
    case springDelay(Int)
    case focusedItemColor(String)
    case focusedHighlightColor(String)

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
        if field == "glyph_span" {
            return glyphSpan(args)
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
            // The palette register says which colour takes ""
            // (`ColorPaletteKeys.followers`, #1856).
            let automatic = ColorPaletteKeys.allowsAutomatic(
                "space_bar.\(field)"
            )
            return (automatic ? automaticColor(args) : color(args))
                .map(keyword)
        }
        return .failure("unknown space bar setting: \(field)")
    }

    private static func parseChoice(
        field: String,
        args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError>? {
        switch field {
        case "edge":
            return BarSettingChoice.edge(args).map { parsed in
                parsed.screen.map {
                    .screenEdge(parsed.edge, screen: $0, among: [])
                } ?? .edge(parsed.edge)
            }
        case "active_indicator":
            return BarSettingChoice.value(
                args,
                SpaceBarStyle.ActiveIndicator.self
            ).map(Self.activeIndicator)
        case "inactive_content":
            return BarSettingChoice.value(
                args,
                SpaceBarStyle.InactiveContent.self
            ).map(Self.inactiveContent)
        case "item_label":
            return BarSettingChoice.value(
                args,
                SpaceBarStyle.ItemLabel.self
            ).map(Self.itemLabel)
        default:
            return nil
        }
    }

    private static var boolFields: [String: (Bool) -> SpaceBarCommandSetting] {
        [
            "enabled": Self.enabled,
            "reserve": Self.reserve,
            "show_front_app": Self.showFrontApp,
            "hide_empty": Self.hideEmpty,
            "sticky_badge": Self.stickyBadge,
            "group_adjacent_windows": Self.groupAdjacentWindows,
        ]
    }

    private static var numberFields:
        [String: (CGFloat) -> SpaceBarCommandSetting]
    {
        [
            "active_dim_factor": Self.activeDimFactor,
            "glyph_gap": Self.glyphGap,
        ]
    }

    /// Color setting field constructors by wire key. Internal, not
    /// private: the palette shelf (#375) routes through these same
    /// validated setters; see the AppBar twin.
    static var colorFields: [String: (String) -> SpaceBarCommandSetting] {
        [
            "focused_item_color": Self.focusedItemColor,
            "focused_highlight_color": Self.focusedHighlightColor,
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
    private static func glyphSpan(
        _ args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError> {
        guard let value = args.first?.numberValue,
            value.isFinite
        else {
            return .failure("expected a glyph count")
        }
        let range = SpaceBarStyle.glyphSpanRange
        // Clamp as Double BEFORE Int(...) — `Int(1e300)` traps
        // (#58).
        let clamped = min(
            max(value.rounded(), Double(range.lowerBound)),
            Double(range.upperBound)
        )
        return .success(.glyphSpan(Int(clamped)))
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

    /// A colour that also takes `""`, Automatic
    /// (`ColorPaletteKeys.followers`, #1856).
    private static func automaticColor(
        _ args: [JSONValue]
    ) -> Result<String, AppBarSettingError> {
        guard let hex = args.first?.stringValue,
            hex.isEmpty || DragVisual.parseHex(hex) != nil
        else {
            return .failure("expected #RRGGBB, #RRGGBBAA or \"\"")
        }
        return .success(hex)
    }

    /// Applies setting value to SpaceBarStyle.
    func apply(to style: inout SpaceBarStyle) {
        switch self {
        case .enabled(let value): style.enabled = value
        case .reserve(let value): style.reserve = value
        case .edge(let value): style.setEdge(value)
        case .screenEdge(let value, let screen, let screens):
            style.setEdge(value, on: screen, among: screens)
        case .glyphSpan(let value): style.glyphSpan = value
        case .glyphGap(let value):
            style.glyphGap = SpaceBarStyle.clampGlyphGap(value)
        case .inactiveContent(let value):
            style.inactiveContent = value
        case .itemLabel(let value):
            style.itemLabel = value
        case .frontAppTitleCap(let value):
            style.frontAppTitleCap = value
        case .activeIndicator(let value):
            style.activeIndicator = value
        case .activeDimFactor(let value):
            style.activeDimFactor = AppBarStyle.clampDim(value)
        case .showFrontApp(let value):
            style.showFrontApp = value
        case .hideEmpty(let value): style.hideEmpty = value
        case .groupAdjacentWindows(let value):
            style.groupAdjacentWindows = value
        case .stickyBadge(let value): style.stickyBadge = value
        case .springDelay(let value):
            style.springDelay = value
        case .focusedItemColor(let value):
            style.focusedItemColor = value
        case .focusedHighlightColor(let value):
            style.focusedHighlightColor = value
        }
    }
}

extension SpaceBarCommandSetting {
    /// This setting with a screened edge judged over `screens`.
    func scoped(to screens: Set<String>) -> Self {
        guard case .screenEdge(let edge, let screen, _) = self else {
            return self
        }
        return .screenEdge(edge, screen: screen, among: screens)
    }
}
