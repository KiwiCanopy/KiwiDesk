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
    case itemSize(CGFloat)
    case itemGap(CGFloat)
    case fontSize(CGFloat)
    case glyphCap(Int)
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
        case "background_style":
            return choice(
                args,
                SpaceBarStyle.BackgroundStyle.self,
                "boxed|plain"
            ).map(Self.backgroundStyle)
        case "background_fit":
            return choice(
                args,
                SpaceBarStyle.BackgroundFit.self,
                "full|hug"
            ).map(Self.backgroundFit)
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

    /// Wire-key → color-field constructor. Internal (not private)
    /// so the palette shelf (#375) can route a color path through
    /// the same validated field setters; see the AppBar twin.
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

    /// Milliseconds, clamped to the Space Bar's valid dwell
    /// range — a stored out-of-range value can't spring instantly
    /// or hang.
    private static func springDelay(
        _ args: [JSONValue]
    ) -> Result<SpaceBarCommandSetting, AppBarSettingError> {
        guard let value = args.first?.numberValue,
            value.isFinite
        else {
            return .failure("expected milliseconds")
        }
        let range = SpaceBarStyle.springDelayRange
        // Clamp as Double BEFORE Int(...) — `Int(1e300)` traps,
        // so a config typo would otherwise kill the WM (#58/#386).
        let clamped = min(
            max(value.rounded(), Double(range.lowerBound)),
            Double(range.upperBound)
        )
        return .success(.springDelay(Int(clamped)))
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
        case .thickness(let value):
            style.thickness = max(AppBarStyle.minThickness, value)
        case .itemSize(let value): style.itemSize = value
        case .itemGap(let value): style.itemGap = value
        case .fontSize(let value): style.fontSize = value
        case .glyphCap(let value): style.glyphCap = value
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
