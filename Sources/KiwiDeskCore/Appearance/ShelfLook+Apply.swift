import Foundation

/// One-shot application of a ShelfLook (#1684). Every shelf and bar
/// value routes through the setter its `set_*` command uses, and the
/// sheen through the one `BorderStyle.sheen(from:)` its command
/// shares, so a look can never set a value a command couldn't; an
/// unknown path or a refused value is skipped, never fatal.
extension ShelfLook {
    /// Overwrites the styling this look names, in place (sparse),
    /// then `palette`'s colours when one is handed in. Only the
    /// caller resolves the palette, so nothing changes that the
    /// "use its colours too" tick did not say.
    public func apply(
        to settings: inout TilingSettings,
        palette: ColorPalette? = nil
    ) {
        for path in LookKeys.all {
            guard let value = style[path] else { continue }
            Self.apply(path: path, value: value, to: &settings)
        }
        palette?.apply(to: &settings)
    }

    /// True when applying this look's styling would change nothing
    /// — computed, never stored (the palette rule, #757).
    public func isApplied(to settings: TilingSettings) -> Bool {
        guard style.keys.contains(where: LookKeys.all.contains) else {
            return false
        }
        var painted = settings
        apply(to: &painted)
        return painted == settings
    }

    static func apply(
        path: String,
        value: JSONValue,
        to settings: inout TilingSettings
    ) {
        let parts = path.split(separator: ".").map(String.init)
        guard parts.count == 2 else { return }
        let args = [value]
        switch parts[0] {
        case "kiwishelf":
            guard
                case .success(let setting) =
                    KiwiShelfCommandSetting
                    .parse(field: parts[1], args: args)
            else { return }
            // Glass is one switch over every surface (#1307).
            if case .liquidGlass(let on) = setting {
                settings.setLiquidGlass(on)
            } else {
                setting.apply(to: &settings.kiwishelf)
            }
        case "space_bar":
            if case .success(let setting) =
                SpaceBarCommandSetting
                .parse(field: parts[1], args: args)
            {
                setting.apply(to: &settings.spaceBarStyle)
            }
        case "app_bar":
            if case .success(let setting) =
                AppBarCommandSetting
                .parse(field: parts[1], args: args)
            {
                setting.apply(to: &settings.appBarStyle)
                // A per-layout indicator would hide the look's.
                if case .activeIndicator = setting {
                    settings.monocle.appBar.activeIndicator = nil
                    settings.scrolling.appBar.activeIndicator = nil
                }
            }
        case "border" where parts[1] == "sheen":
            if let sheen = BorderStyle.sheen(from: value) {
                settings.borderStyle.sheen = sheen
            }
        default:
            break
        }
    }
}
