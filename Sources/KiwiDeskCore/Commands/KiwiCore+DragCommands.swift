import Foundation

/// drag.* sub-API: the two drag markers' switches and the drop
/// zone's Liquid Glass (see `DragOverlay`). Their look is fixed
/// (#2797); a retired knob answers through `APIReference.retired`.
extension KiwiCore {
    func dragCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        let visual: WritableKeyPath<TilingSettings, DragVisual>
        switch command {
        case "drag.set_liquid_glass":
            guard let on = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            // Read when a marker shows, so no retile (#1620).
            tiler.settings.dragLiquidGlass = on
            return .ok()
        case "drag.set_ghost_enabled": visual = \.dragGhost
        case "drag.set_drop_zone_enabled": visual = \.dragDropZone
        default:
            return .fail("unknown command: \(command)")
        }
        guard let flag = args.first?.boolValue else {
            return .fail("expected boolean")
        }
        tiler.settings[keyPath: visual].enabled = flag
        return .ok()
    }
}
