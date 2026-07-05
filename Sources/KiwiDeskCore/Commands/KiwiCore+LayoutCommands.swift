import AppKit
import Foundation

/// Layout sub-APIs (stack.* / bsp.* / scroll.* / grid.*) plus
/// animation, sleep/wake, and drag settings.
extension KiwiCore {
    func layoutCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        let response: CommandResponse
        if command.hasPrefix("stack.") {
            response = stackCommand(command, args)
        } else if command.hasPrefix("bsp.") {
            response = bspCommand(command, args)
        } else if command.hasPrefix("scroll.") {
            response = scrollCommand(command, args)
        } else if command.hasPrefix("grid.") {
            response = gridCommand(command, args)
        } else if command.hasPrefix("monocle.") {
            response = monocleCommand(command, args)
        } else if command.hasPrefix("app_bar.") {
            response = barCommand(command, args)
        } else if command.hasPrefix("drag.") {
            response = dragCommand(command, args)
        } else {
            response = settingsCommand(command, args)
        }
        if response.isSuccess {
            retile()
        }
        return response
    }

    // MARK: - stack.*

    private func stackCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "stack.promote", "stack.demote":
            return promoteDemote(command == "stack.promote")
        case "stack.set_master_count":
            guard let count = args.first?.intValue else {
                return .fail("expected count")
            }
            tiler.settings.stack.masterCount = max(1, count)
        case "stack.set_master_ratio":
            guard let ratio = args.first?.numberValue else {
                return .fail("expected ratio")
            }
            tiler.settings.stack.masterRatio =
                min(max(ratio, 0.1), 0.9)
        case "stack.set_overflow_style":
            guard let raw = args.first?.stringValue,
                let style = StackParams.OverflowStyle(
                    rawValue: raw
                )
            else {
                return .fail(
                    "expected cascade_overflow | cascade_all"
                )
            }
            tiler.settings.stack.overflowStyle = style
        case "stack.set_new_window_placement":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.stack.newWindowPlacement = placement
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
    }

    /// Shared parsing for the per-layout
    /// `*.set_new_window_placement` commands.
    private func parsePlacement(
        _ args: [JSONValue]
    ) -> SpawnPlacement? {
        guard let raw = args.first?.stringValue else {
            return nil
        }
        return SpawnPlacement(rawValue: raw)
    }

    private var placementError: CommandResponse {
        .fail(
            "expected first | last | before_focused"
                + " | after_focused"
        )
    }

    private func promoteDemote(
        _ promote: Bool
    ) -> CommandResponse {
        guard let space = activeSpace,
            let focused = space.focused
        else {
            return .fail("no focused window")
        }
        let count = tiler.settings.stack.masterCount
        state.workspaces.withSpace(space.id) {
            if promote {
                $0.promote(focused, masterCount: count)
            } else {
                $0.demote(focused, masterCount: count)
            }
        }
        if activeSpace?.windows != space.windows {
            scheduleZOrderRestore()
        }
        return .ok()
    }

    // MARK: - bsp.*

    private func bspCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "bsp.set_strategy":
            guard let raw = args.first?.stringValue,
                let strategy = BspParams.Strategy(
                    rawValue: raw
                )
            else {
                return .fail(
                    "expected shortest_side|alternating"
                )
            }
            tiler.settings.bsp.strategy = strategy
        case "bsp.set_ratio":
            guard let ratio = args.first?.numberValue else {
                return .fail("expected ratio")
            }
            tiler.settings.bsp.splitRatio =
                min(max(ratio, 0.1), 0.9)
        case "bsp.set_new_window_placement":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.bsp.newWindowPlacement = placement
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
    }

    // MARK: - scroll.*

    private func scrollCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "scroll.set_slot_size":
            guard let first = args.first else {
                return .fail(
                    "expected points, \"NN%\", or 0 for auto"
                )
            }
            if let number = first.numberValue {
                tiler.settings.scrolling.slotSize =
                    number <= 0
                    ? .auto : .points(max(CGFloat(number), 100))
            } else if let string = first.stringValue,
                string.hasSuffix("%"),
                let percent = Double(string.dropLast())
            {
                tiler.settings.scrolling.slotSize =
                    .fraction(min(max(percent / 100, 0.05), 1))
            } else {
                return .fail(
                    "expected points, \"NN%\", or 0 for auto"
                )
            }
        case "scroll.set_anchor":
            guard let raw = args.first?.stringValue,
                let anchor = ScrollingParams.Anchor(
                    rawValue: raw
                )
            else {
                return .fail("expected center|left|right")
            }
            tiler.settings.scrolling.anchor = anchor
        case "scroll.set_orientation":
            guard let raw = args.first?.stringValue,
                let orientation = ScrollingParams.Orientation(
                    rawValue: raw
                )
            else {
                return .fail("expected horizontal|vertical")
            }
            tiler.settings.scrolling.orientation = orientation
            warnOnScrollBarMismatch()
        case "scroll.set_speed":
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            tiler.animation.durationMS = ms
        case "scroll.set_new_window_placement":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.scrolling.newWindowPlacement =
                placement
        default:
            guard command.hasPrefix("scroll.set_app_bar_") else {
                return .fail("unknown command: \(command)")
            }
            let field = String(
                command.dropFirst("scroll.set_app_bar_".count)
            )
            let response = applyBarOverride(
                field: field,
                args,
                into: &tiler.settings.scrolling.appBar
            )
            if response.isSuccess, field == "position" {
                warnOnScrollBarMismatch()
            }
            return response
        }
        return .ok()
    }

    private func warnOnScrollBarMismatch() {
        warnOnBarPositionMismatch(
            host: tiler.settings.scrolling,
            layout: "scroll",
            orientation: tiler.settings.scrolling.orientation
                .rawValue
        )
    }

    // MARK: - grid.*

    private func gridCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "grid.set_type":
            guard let raw = args.first?.stringValue,
                let type = GridParams.GridType(rawValue: raw)
            else {
                return .fail("expected dynamic|rigid")
            }
            tiler.settings.grid.type = type
        case "grid.set_fill_empty_space":
            guard let fill = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.settings.grid.fillEmptySpace = fill
        case "grid.set_split_direction":
            guard let raw = args.first?.stringValue,
                let direction = GridParams.SplitDirection(
                    rawValue: raw
                )
            else {
                return .fail("expected horizontal|vertical")
            }
            tiler.settings.grid.splitDirection = direction
        case "grid.set_dimensions":
            guard let cols = args.first?.intValue,
                let rows = args.dropFirst().first?.intValue
            else {
                return .fail("expected columns and rows")
            }
            tiler.settings.grid.columns = max(1, cols)
            tiler.settings.grid.rows = max(1, rows)
        case "grid.set_new_window_placement":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.grid.newWindowPlacement = placement
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
    }

    // MARK: - Global toggles

    private func settingsCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "enable_animations":
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.animation.isEnabled = enabled
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
