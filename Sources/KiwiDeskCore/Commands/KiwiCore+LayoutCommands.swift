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
        if command.hasPrefix("animations.") {
            response = animationsCommand(command, args)
        } else if command.hasPrefix("stack.") {
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
    /// `*.set_new_window_placement` commands. Internal so the
    /// split-out `scroll.*` / settings command files can reuse it.
    func parsePlacement(
        _ args: [JSONValue]
    ) -> SpawnPlacement? {
        guard let raw = args.first?.stringValue else {
            return nil
        }
        return SpawnPlacement(rawValue: raw)
    }

    var placementError: CommandResponse {
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

}
