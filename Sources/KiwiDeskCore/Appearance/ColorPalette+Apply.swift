import Foundation

/// Applying a palette onto a settings value — one shot, no live
/// link (#375). Each color routes through the SAME validated field
/// setter the per-key `set_*_color` commands use (bars) or a direct
/// write (border, drag), so a palette can never set a color a
/// command couldn't. Invalid hex or unknown path = skipped.
extension ColorPalette {
    /// Overwrites `settings`' colors with this palette's, in place.
    /// Absent keys are left untouched (sparse).
    public func apply(to settings: inout TilingSettings) {
        for (path, hex) in colors {
            guard DragVisual.parseHex(hex) != nil else { continue }
            apply(path: path, hex: hex, to: &settings)
        }
    }

    private func apply(
        path: String,
        hex: String,
        to settings: inout TilingSettings
    ) {
        let parts = path.split(separator: ".").map(String.init)
        switch parts.first {
        case "app_bar" where parts.count == 2:
            AppBarCommandSetting.colorFields[parts[1]]?(hex)
                .apply(to: &settings.appBarStyle)
        case "space_bar" where parts.count == 2:
            SpaceBarCommandSetting.colorFields[parts[1]]?(hex)
                .apply(to: &settings.spaceBarStyle)
        case "border" where parts.count == 2:
            applyBorder(parts[1], hex, to: &settings.borderStyle)
        case "drag" where parts.count == 3:
            applyDrag(parts[1], parts[2], hex, to: &settings)
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

    private func applyDrag(
        _ element: String,
        _ key: String,
        _ hex: String,
        to settings: inout TilingSettings
    ) {
        let keyPath: WritableKeyPath<TilingSettings, DragVisual>
        switch element {
        case "ghost": keyPath = \.dragGhost
        case "drop_zone": keyPath = \.dragDropZone
        default: return
        }
        switch key {
        case "border_color":
            settings[keyPath: keyPath].borderColor = hex
        case "fill_color":
            settings[keyPath: keyPath].fillColor = hex
        default: break
        }
    }
}
