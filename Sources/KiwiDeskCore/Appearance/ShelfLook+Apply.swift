import Foundation

/// One-shot application of a ShelfLook (#1684). Every value is
/// PARSED by the parser its `set_*` command uses — the sheen by the
/// one `BorderStyle.sheen(from:)` its command shares — so a look can
/// never set a value a command couldn't; an unknown path or a
/// refused value is skipped, never fatal. Two writes reach further
/// than their command, by ruling (`docs/design-decisions.md` ▸ A
/// look is KiwiShelf's styling): glass writes every glass leaf
/// (#1307), and the App Bar indicator clears the per-layout
/// overrides that would hide it.
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

    /// True when a click would change nothing — computed, never
    /// stored (the palette rule, #757). So a look saved from glass
    /// leaves that disagree, or under a per-layout indicator, reads
    /// unapplied until clicked, since the click would converge them.
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
