import Foundation

/// One-shot application of ColorPalette onto TilingSettings
/// (#375). Each color routes through the SAME validated field
/// setter the per-key `set_*_color` commands use, so a palette
/// can never set a color a command couldn't. Invalid hex or
/// unknown path = skipped, never fatal.
extension ColorPalette {
    /// Overwrites `settings`' colors with this palette's, in place (sparse).
    public func apply(to settings: inout TilingSettings) {
        for (path, hex) in colors {
            guard isPaintable(hex, at: path) else { continue }
            apply(path: path, hex: hex, to: &settings)
        }
    }

    /// A hex, or the empty "Automatic" value on the one kind of
    /// path that has an adaptive face
    /// (`ColorPaletteKeys.allowsAutomatic`). Anything else is
    /// skipped rather than fatal.
    private func isPaintable(_ hex: String, at path: String) -> Bool {
        if hex.isEmpty {
            return ColorPaletteKeys.allowsAutomatic(path)
        }
        return DragVisual.parseHex(hex) != nil
    }

    private func apply(
        path: String,
        hex: String,
        to settings: inout TilingSettings
    ) {
        let parts = path.split(separator: ".").map(String.init)
        switch parts.first {
        case "kiwishelf" where parts.count == 2:
            if let field = KiwiShelfCommandSetting.colorFields[parts[1]] {
                settings.kiwishelf[keyPath: field] = hex
            }
        case "space_bar" where parts.count == 2:
            SpaceBarCommandSetting.colorFields[parts[1]]?(hex)
                .apply(to: &settings.spaceBarStyle)
        case "border" where parts.count == 2:
            applyBorder(parts[1], hex, to: &settings.borderStyle)
        // The mark tints (#678 Colours phase, #2671). Each struct
        // IS the mark, so its one color key is bare `color`.
        case "sticky" where parts == ["sticky", "color"]:
            settings.stickyStyle.color = hex
        case "floating" where parts == ["floating", "color"]:
            settings.floatingStyle.color = hex
        case "pocket" where parts == ["pocket", "color"]:
            settings.pocketStyle.color = hex
        default:
            break
        }
    }

    private func applyBorder(
        _ key: String,
        _ hex: String,
        to border: inout BorderStyle
    ) {
        switch key {
        case "focused_color": border.focusedColor = hex
        case "unfocused_color": border.unfocusedColor = hex
        default: break
        }
    }
}
