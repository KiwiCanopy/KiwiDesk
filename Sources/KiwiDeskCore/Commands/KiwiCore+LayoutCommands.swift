import AppKit
import Foundation

/// Layout sub-API dispatch (stack.* / bsp.* / scroll.* / grid.* /
/// monocle.*) plus animation, sleep/wake, and drag settings. Each
/// layout's own setters live in a sibling file
/// (`KiwiCore+<Layout>Commands`); this routes to them and retiles
/// on success.
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

    /// Shared parsing for the per-layout
    /// `*.set_new_window_placement` commands. Internal so the
    /// split-out layout command files can reuse it.
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
}
