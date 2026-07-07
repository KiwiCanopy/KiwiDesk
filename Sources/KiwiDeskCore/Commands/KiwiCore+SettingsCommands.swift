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
            // Deprecated alias for `animations.set_duration`.
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            onLog(
                "set_animation_duration is deprecated — use "
                    + "animations.set_duration(ms)"
            )
            setAnimationDuration(ms)
        case "set_space_animation":
            // Deprecated alias for `animations.set_on_space_change`
            // (issue #11). Still works so existing configs load.
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            onLog(
                "set_space_animation is deprecated — use "
                    + "animations.set_on_space_change(bool)"
            )
            tiler.settings.animations.onSpaceChange = enabled
        case "set_mouse_resize":
            guard let raw = args.first?.stringValue,
                let mode = MouseResizeMode(rawValue: raw)
            else {
                return .fail("expected layout|snap_back")
            }
            tiler.settings.mouseResize = mode
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

    /// `animations.*` toggles and duration knobs (issues #11,
    /// #51). Toggles and duration values persist in
    /// `settings.animations`; the engine is updated in place.
    func animationsCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        // Duration knobs take Int, not Bool; handle before the
        // Bool guard below.
        switch command {
        case "animations.set_duration":
            // Persisted per-profile (issue #51). Writes both
            // the settings struct and the engine so the value
            // is live immediately AND captured on next save.
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            setAnimationDuration(ms)
            return .ok()
        case "animations.set_scroll_speed":
            // The scroll-specific duration knob, split from
            // `animations.set_duration` (issue #51).
            // `scroll.set_speed` is the deprecated alias.
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            setScrollSpeed(ms)
            return .ok()
        default:
            break
        }
        guard let enabled = args.first?.boolValue else {
            return .fail("expected boolean")
        }
        switch command {
        case "animations.set_on_space_change":
            tiler.settings.animations.onSpaceChange = enabled
        case "animations.set_on_scrolling":
            tiler.settings.animations.onScrolling = enabled
        case "animations.set_on_window_resize":
            tiler.settings.animations.onWindowResize = enabled
        case "animations.set_on_window_swap":
            tiler.settings.animations.onWindowSwap = enabled
        case "animations.set_on_relayout":
            tiler.settings.animations.onRelayout = enabled
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
    }
}
