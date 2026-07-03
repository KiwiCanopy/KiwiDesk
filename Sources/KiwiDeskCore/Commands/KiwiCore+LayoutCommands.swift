import AppKit
import Foundation

/// Serial queue for z-order raises. AX raise calls are
/// blocking IPC; running them here keeps the main thread free
/// and their order strict.
private let zOrderQueue = DispatchQueue(
    label: "org.kiwidesk.zorder",
    qos: .userInteractive
)

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
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
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
            scheduleStackZOrderRestore()
        }
        return .ok()
    }

    // MARK: - Stack z-order

    /// Requests a stack z-order restore after a window
    /// crossed the master/stack boundary. Deferred until all
    /// animations settle: a raise is only processed once the
    /// target app's main thread is free, and while frames are
    /// still being applied, slow apps process their raise
    /// late and end up out of order.
    func scheduleStackZOrderRestore() {
        pendingStackZOrderRestore = true
        if tiler.animation.activeCount == 0 {
            runPendingStackZOrderRestore()
        }
    }

    /// Runs a scheduled restore (called when animations end).
    func runPendingStackZOrderRestore() {
        guard pendingStackZOrderRestore else { return }
        pendingStackZOrderRestore = false
        restoreStackZOrder()
    }

    /// Re-raises the stack zone top to bottom, so upper
    /// windows sit behind lower ones and every title bar of
    /// the cascade stays visible. A plain focus change still
    /// brings the focused window to the front, which is the
    /// expected override. Raises run sequentially on one
    /// queue: each call returns only after the target app
    /// processed it, which keeps the order across apps.
    private func restoreStackZOrder() {
        guard let space = activeSpace, space.mode == .stack
        else { return }
        let boundary = max(1, tiler.settings.stack.masterCount)
        guard space.windows.count > boundary else { return }
        let ordered = space.windows[boundary...].compactMap {
            eventLoop.element(for: $0)
        }
        guard !ordered.isEmpty else { return }
        nonisolated(unsafe) let elements = ordered
        zOrderQueue.async {
            for element in elements {
                AXHelper.raiseQuietly(element)
            }
        }
    }

    /// Whether swapping these two windows moves one across
    /// the stack layout's master/stack boundary.
    func crossesStackBoundary(
        _ a: WindowID,
        _ b: WindowID,
        in space: Space
    ) -> Bool {
        guard space.mode == .stack else { return false }
        let boundary = max(1, tiler.settings.stack.masterCount)
        guard let indexA = space.windows.firstIndex(of: a),
            let indexB = space.windows.firstIndex(of: b)
        else { return false }
        return (indexA < boundary) != (indexB < boundary)
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
        case "scroll.set_width":
            guard let width = args.first?.numberValue else {
                return .fail("expected width")
            }
            tiler.settings.scrolling.windowWidth =
                max(CGFloat(width), 100)
        case "scroll.set_anchor":
            guard let raw = args.first?.stringValue,
                let anchor = ScrollingParams.Anchor(
                    rawValue: raw
                )
            else {
                return .fail("expected center|left|right")
            }
            tiler.settings.scrolling.anchor = anchor
        case "scroll.set_speed":
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            tiler.animation.durationMS = ms
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
        case "set_drag_ghost":
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.settings.dragShowGhost = enabled
        case "set_drag_drop_zone":
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.settings.dragShowDropZone = enabled
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
