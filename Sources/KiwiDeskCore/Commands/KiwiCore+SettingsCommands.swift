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
        case "set_mouse_resize":
            guard let raw = args.first?.stringValue,
                let mode = MouseResizeMode(rawValue: raw)
            else {
                return .expected(MouseResizeMode.self)
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
        case "set_space_icon":
            // Optional recognition icon per space (#68) — an
            // SF Symbol name, emoji, or single character (the
            // mode-icon grammar). An empty icon clears.
            guard let space = args.first?.stringValue,
                !space.isEmpty,
                let icon = args.dropFirst().first?.stringValue
            else {
                return .fail("expected space id and icon")
            }
            tiler.settings.spaceIcons[SpaceID(space)] =
                icon.isEmpty ? nil : icon
        case "set_fallback_space":
            // The explicit rehome target (#68): where windows
            // land when a profile switch drops their space. An
            // empty id clears back to the order-derived
            // fallback. Captured into the profile on save.
            guard let raw = args.first?.stringValue else {
                return .fail("expected space id")
            }
            if raw.isEmpty {
                fallbackSpace = nil
                return .ok()
            }
            guard
                state.workspaces[SpaceID(raw)] != nil
            else {
                return .fail("unknown space: \(raw)")
            }
            fallbackSpace = SpaceID(raw)
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
            // Engine syncs via TilingEngine.settings.didSet.
            tiler.settings.animations.durationMS = ms
            return .ok()
        case "animations.set_scroll_speed":
            // The scroll-specific duration knob, split from
            // `animations.set_duration` (issue #51).
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            tiler.settings.animations.scrollSpeedMS = ms
            return .ok()
        case "animations.set_size_policy":
            // Experimental (#47), engine-only — not persisted to a
            // profile. Flip live to compare the throttled-smooth
            // grow against the shipping mid-slide on device.
            guard let raw = args.first?.stringValue,
                let policy = SizePolicy(rawValue: raw)
            else { return .expected(SizePolicy.self) }
            tiler.animation.sizePolicy = policy
            return .ok()
        case "animations.set_size_rate":
            // Size-set cap in Hz for `smooth` (#47), clamped 1–120.
            // Zero or negative restores the per-tick default (no
            // throttle), matching the engine's `nil`.
            guard let hz = args.first?.intValue else {
                return .fail("expected hertz")
            }
            tiler.animation.sizeRateHz = hz > 0 ? hz : nil
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

    /// `mouse.*` pointer-behaviour toggles (#186). Persist in
    /// `settings.mouse` so they ride the profile split like
    /// the animation toggles above.
    func mouseCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let enabled = args.first?.boolValue else {
            return .fail("expected boolean")
        }
        switch command {
        case "mouse.set_follows_focus":
            tiler.settings.mouse.followsFocus = enabled
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
    }

    /// `quit.*` teardown placement (#197). Persists in
    /// `settings.quitLayout`; read only when the app stops
    /// (`gatherWindows`), so the outer dispatcher routes it
    /// past layoutCommand's forced-retile trailer.
    func quitCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "quit.set_layout":
            guard
                let raw = args.first?.stringValue,
                let style = QuitLayoutStyle(rawValue: raw)
            else {
                return .expected(QuitLayoutStyle.self)
            }
            tiler.settings.quitLayout = style
        case "quit.set_grid_target_depth":
            guard
                let raw = args.first?.numberValue,
                raw.isFinite
            else {
                return .fail("expected depth")
            }
            let range = QuitGridLayout.targetDepthRange
            // Bounds-check as Double BEFORE Int(...) —
            // `Int(1e300)` traps, so a config typo would
            // otherwise kill the WM (the #58 lesson).
            let rounded = raw.rounded()
            guard
                rounded >= Double(range.lowerBound),
                rounded <= Double(range.upperBound)
            else {
                return .fail(
                    "expected \(range.lowerBound)"
                        + "-\(range.upperBound)"
                )
            }
            tiler.settings.quitGridTargetDepth = Int(rounded)
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
    }
}
