import AppKit
import Foundation

/// Global toggles (animation, sleep/wake, mouse resize, placement
/// override) — the fall-through for commands with no layout prefix.
/// Split out of `KiwiCore+LayoutCommands` for file size.
extension KiwiCore {
    func settingsCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "set_animation_duration":
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            tiler.animation.durationMS = ms
        case "set_space_animation":
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.animateSpaceSwitch = enabled
        case "set_mouse_resize":
            guard let raw = args.first?.stringValue,
                let mode = MouseResizeMode(rawValue: raw)
            else {
                return .fail("expected layout|snap_back")
            }
            tiler.mouseResize = mode
        case "enable_wake_restore":
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            sleepWake.isEnabled = enabled
        case "set_wake_restore_delay":
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            sleepWake.restoreDelayMS = max(0, ms)
        case "set_new_window_placement_override":
            guard let space = args.first?.stringValue else {
                return .fail("expected space id and placement")
            }
            guard
                let placement = parsePlacement(
                    Array(args.dropFirst())
                )
            else {
                return placementError
            }
            tiler.settings.placementOverride[SpaceID(space)] =
                placement
        default:
            var message = "unknown command: \(command)"
            if let hint = APIReference.suggestion(
                for: command
            ) {
                message += " — did you mean '\(hint)'?"
            }
            message += " (run 'help' for all commands)"
            return .fail(message)
        }
        return .ok()
    }
}
