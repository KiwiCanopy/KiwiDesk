import Foundation

/// drag.* sub-API: the visuals shown while a tiled window is
/// dragged (see DragOverlay). Each element (ghost, drop_zone)
/// has an on/off switch plus border/fill toggles and colors.
extension KiwiCore {
    func dragCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command == "drag.set_corner_radius" {
            guard let radius = args.first?.numberValue else {
                return .fail("expected radius (pt)")
            }
            tiler.settings.dragCornerRadius = max(0, radius)
            return .ok()
        }
        let prefix = "drag.set_"
        guard command.hasPrefix(prefix) else {
            return .fail("unknown command: \(command)")
        }
        let setter = String(command.dropFirst(prefix.count))
        if setter.hasPrefix("ghost_") {
            return setVisual(
                \.dragGhost,
                String(setter.dropFirst("ghost_".count)),
                args
            )
        }
        if setter.hasPrefix("drop_zone_") {
            return setVisual(
                \.dragDropZone,
                String(setter.dropFirst("drop_zone_".count)),
                args
            )
        }
        return .fail("unknown command: \(command)")
    }

    private func setVisual(
        _ visual: WritableKeyPath<TilingSettings, DragVisual>,
        _ property: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch property {
        case "enabled", "border", "fill":
            guard let flag = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            switch property {
            case "enabled":
                tiler.settings[keyPath: visual].enabled = flag
            case "border":
                tiler.settings[keyPath: visual].border = flag
            default:
                tiler.settings[keyPath: visual].fill = flag
            }
        case "border_width":
            guard let thickness = args.first?.numberValue else {
                return .fail("expected thickness (pt)")
            }
            tiler.settings[keyPath: visual].borderWidth =
                max(0, thickness)
        case "border_alignment":
            guard let val = args.first?.stringValue,
                let alignment = BorderAlignment(rawValue: val)
            else {
                return .expected(BorderAlignment.self)
            }
            tiler.settings[keyPath: visual].borderAlignment =
                alignment
        case "border_color", "fill_color":
            guard let hex = args.first?.stringValue,
                DragVisual.parseHex(hex) != nil
            else {
                return .fail("expected #RRGGBB or #RRGGBBAA")
            }
            if property == "border_color" {
                tiler.settings[keyPath: visual].borderColor =
                    hex
            } else {
                tiler.settings[keyPath: visual].fillColor =
                    hex
            }
        default:
            return .fail("unknown drag setting: \(property)")
        }
        return .ok()
    }
}
