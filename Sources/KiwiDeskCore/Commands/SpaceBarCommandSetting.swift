import CoreGraphics
import Foundation

/// Parsed `space_bar.set_*` command setting representation (#293).
enum SpaceBarCommandSetting {
    case enabled(Bool)
    case edge(AppBarEdge)
    case alignment(SpaceBarStyle.Alignment)
    case thickness(CGFloat)
    case itemSize(CGFloat)
    case itemGap(CGFloat)
    case fontSize(CGFloat)
    case glyphCap(Int)
    case titleCap(Int)
    case iconSource(BarAppIconSource)
    case backgroundStyle(SpaceBarStyle.BackgroundStyle)
    case liquidGlass(Bool)
    case backgroundFit(SpaceBarStyle.BackgroundFit)
    case activeIndicator(SpaceBarStyle.ActiveIndicator)
    case cornerRoundness(CGFloat)
    case dimFactor(CGFloat)
    case activeDimFactor(CGFloat)
    case showFrontApp(Bool)
    case hideEmpty(Bool)
    case stickyBadge(Bool)
    case springDelay(Int)
    case itemColor(String)
    case activeItemColor(String)
    case focusedItemColor(String)
    case hoverFillColor(String)
    case hoverItemColor(String)
    case fillColor(String)
    case highlightColor(String)
    case groupBadgeColor(String)
    case groupBadgeTextColor(String)

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
        if field == "title_cap" {
            return titleCap(args)
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
            return BarSettingChoice.value(
                args,
                AppBarEdge.self
            ).map(Self.edge)
        case "alignment":
            return BarSettingChoice.value(
                args,
                SpaceBarStyle.Alignment.self
            ).map(Self.alignment)
        case "icon_source":
            return BarSettingChoice.value(
                args,
                BarAppIconSource.self
            ).map(Self.iconSource)
        case "background_style":
            return BarSettingChoice.value(
                args,
                SpaceBarStyle.BackgroundStyle.self
            ).map(Self.backgroundStyle)
        case "background_fit":
            return BarSettingChoice.value(
                args,
                SpaceBarStyle.BackgroundFit.self
            ).map(Self.backgroundFit)
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
            "liquid_glass": Self.liquidGlass,
        ]
    }

    private static var numberFields:
        [String: (CGFloat) -> SpaceBarCommandSetting]
    {
        [
            "thickness": Self.thickness,
            "item_size": Self.itemSize,
            "item_gap": Self.itemGap,
            "font_size": Self.fontSize,
            "corner_roundness": Self.cornerRoundness,
            "dim_factor": Self.dimFactor,
            "active_dim_factor": Self.activeDimFactor,
        ]
    }

    /// Color setting field constructors by wire key (#375).
    static var colorFields: [String: (String) -> SpaceBarCommandSetting] {
        [
            "item_color": Self.itemColor,
            "active_item_color": Self.activeItemColor,
            "focused_item_color": Self.focusedItemColor,
            "hover_fill_color": Self.hoverFillColor,
            "hover_item_color": Self.hoverItemColor,
            "fill_color": Self.fillColor,
            "highlight_color": Self.highlightColor,
            "group_badge_color": Self.groupBadgeColor,
            "group_badge_text_color": Self.groupBadgeTextColor,
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
        // Clamp as Double before Int conversion (#58, #386).
        let clamped = min(
            max(value.rounded(), Double(range.lowerBound)),
            Double(range.upperBound)
        )
        return .success(.springDelay(Int(clamped)))
    }

    /// Parses title character cap (#58).
    private static func titleCap(
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
        return .success(.titleCap(Int(clamped)))
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
        // Clamp as Double before Int conversion (#58).
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
        case .edge(let value): style.edge = value
        case .alignment(let value): style.alignment = value
        case .thickness(let value):
            style.thickness = max(AppBarStyle.minThickness, value)
        case .itemSize(let value): style.itemSize = value
        case .itemGap(let value): style.itemGap = value
        case .fontSize(let value): style.fontSize = value
        case .glyphCap(let value): style.glyphCap = value
        case .titleCap(let value): style.titleCap = value
        case .iconSource(let value): style.iconSource = value
        case .backgroundStyle(let value):
            style.backgroundStyle = value
        case .liquidGlass(let value): style.liquidGlass = value
        case .backgroundFit(let value):
            style.backgroundFit = value
        case .activeIndicator(let value):
            style.activeIndicator = value
        case .cornerRoundness(let value):
            style.cornerRoundness = value
        case .dimFactor(let value):
            style.dimFactor = AppBarStyle.clampDim(value)
        case .activeDimFactor(let value):
            style.activeDimFactor = AppBarStyle.clampDim(value)
        case .showFrontApp(let value):
            style.showFrontApp = value
        case .hideEmpty(let value): style.hideEmpty = value
        case .stickyBadge(let value): style.stickyBadge = value
        case .springDelay(let value):
            style.springDelay = value
        case .itemColor(let value): style.itemColor = value
        case .activeItemColor(let value):
            style.activeItemColor = value
        case .focusedItemColor(let value):
            style.focusedItemColor = value
        case .hoverFillColor(let value): style.hoverFillColor = value
        case .hoverItemColor(let value):
            style.hoverItemColor = value
        case .fillColor(let value): style.fillColor = value
        case .highlightColor(let value):
            style.highlightColor = value
        case .groupBadgeColor(let value):
            style.groupBadgeColor = value
        case .groupBadgeTextColor(let value):
            style.groupBadgeTextColor = value
        }
    }
}
