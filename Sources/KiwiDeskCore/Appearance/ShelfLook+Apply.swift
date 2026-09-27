import Foundation

/// One-shot application of a ShelfLook (#1684). Every value routes
/// through the SAME validated setter its `set_*` command uses, so
/// a look can never set a value a command couldn't; an unknown
/// path or a value its setter refuses is skipped, never fatal.
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

    /// True when every styling value this look names matches
    /// `settings`, compared after routing through the setters —
    /// computed, never stored (the palette rule, #757).
    public func isApplied(to settings: TilingSettings) -> Bool {
        let named = style.keys.filter(LookKeys.all.contains)
        guard !named.isEmpty else { return false }
        var painted = settings
        apply(to: &painted)
        return LookKeys.extract(from: painted)
            == LookKeys.extract(from: settings)
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
            if case .success(let setting) =
                KiwiShelfCommandSetting
                .parse(field: parts[1], args: args)
            {
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
            }
        case "border" where parts[1] == "sheen":
            if let sheen = value.numberValue, sheen.isFinite {
                settings.borderStyle.sheen = BorderStyle.clampSheen(sheen)
            }
        default:
            break
        }
    }
}
