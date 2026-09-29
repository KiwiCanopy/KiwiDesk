import Foundation

/// One-shot application of a ShelfLook (#1684). Every value is
/// parsed by its `set_*` command's parser — the border's by
/// `BorderCommandSetting` (#1739) — except the stored gaps, which
/// the config's own decoder reads (`Gaps.stored`); either way a
/// look can never set a value a command couldn't, and an unknown
/// path or a refused value is skipped, never fatal. Two writes
/// reach further than their COMMAND, by ruling
/// (`docs/design-decisions.md` ▸ A look is KiwiShelf's styling):
/// glass writes every glass leaf (#1307), and the App Bar
/// indicator clears the per-layout overrides that would hide it.
extension ShelfLook {
    /// Overwrites the styling this look names, in place (sparse),
    /// then its colours — every colour path, since a look owns
    /// them whole (#1752).
    public func apply(to settings: inout TilingSettings) {
        applyStyle(to: &settings)
        ColorPalette(name: name, colors: colors).apply(to: &settings)
    }

    /// True when a click would change nothing — computed, never
    /// stored (the palette rule, #757). Judges an ADMITTED look
    /// (`admitted`), whose colours are complete. So a look saved from glass
    /// leaves that disagree, or under a per-layout indicator, reads
    /// unapplied until clicked, since the click would converge them.
    public func isApplied(to settings: TilingSettings) -> Bool {
        guard isStyleApplied(to: settings) else { return false }
        // By parsed colour, the palette's rule: `#8db354` and
        // `#8DB354FF` are one answer (`ColorPalette.sameColor`); a
        // look read through `admitted` carries every path.
        return ColorPalette(name: name, colors: colors)
            .isApplied(to: settings)
    }

    /// How far this look is live in `settings` (#1752): the one
    /// reading a look tile marks from, in Settings and the tour.
    public func match(_ settings: TilingSettings) -> LookMatch {
        guard isStyleApplied(to: settings) else { return .none }
        return isApplied(to: settings) ? .applied : .otherColors
    }

    /// `isApplied` over the styling alone: the look's shape is
    /// live, whatever colours it wears now (#1752).
    public func isStyleApplied(to settings: TilingSettings) -> Bool {
        guard style.keys.contains(where: LookKeys.all.contains) else {
            return false
        }
        var painted = settings
        applyStyle(to: &painted)
        return painted == settings
    }

    private func applyStyle(to settings: inout TilingSettings) {
        for path in LookKeys.all {
            guard let value = style[path] else { continue }
            Self.apply(path: path, value: value, to: &settings)
        }
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
        case "border":
            if case .success(let setting)? =
                BorderCommandSetting
                .parse(field: parts[1], args: args)
            {
                setting.apply(to: &settings.borderStyle)
            }
        case "gap" where parts[1] == "global":
            // Only the global gaps; a Space's override stays (#1739).
            if let gaps = Gaps.stored(value) {
                settings.gapsGlobal = gaps
            }
        default:
            break
        }
    }
}

/// A look tile's mark (#1752): `otherColors` is the look's shape
/// wearing colours it does not own — a palette applied since, or
/// a colour edited.
public enum LookMatch: Sendable, Equatable {
    case applied
    case otherColors
    case none
}
