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
        // Reset the per-dispatch z-order deferral (#153); a
        // reordering command below arms it, and it is flushed
        // strictly after this dispatch's forced retile.
        deferredCommandZOrderRestore = false
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
        } else if command.hasPrefix("track.") {
            response = trackCommand(command, args)
        } else if command.hasPrefix("app_bar.") {
            response = barCommand(command, args)
        } else if command.hasPrefix("space_bar.") {
            response = spaceBarCommand(command, args)
        } else if command.hasPrefix("drag.") {
            response = dragCommand(command, args)
        } else if command.hasPrefix("border.") {
            response = borderCommand(command, args)
        } else if command.hasPrefix("sticky.") {
            response = stickyCommand(command, args)
        } else if command.hasPrefix("floating.") {
            response = floatingCommand(command, args)
        } else if command.hasPrefix("mouse.") {
            response = mouseCommand(command, args)
        } else {
            response = settingsCommand(command, args)
        }
        if response.isSuccess {
            // Forced: these are explicit config applies from
            // Lua/CLI (AGENTS.md §5) — un-forced, the engine's
            // ±2 pt tolerance would swallow a small ratio
            // nudge exactly like the 1 pt gap edit that
            // motivated the guardrail.
            retile(
                force: true,
                sizeIntent: Self.sizeIntent(for: command)
            )
            // Now that the reorder's animations are in flight,
            // arm the deferred z-order restore (#153) — it rides
            // their settle instead of the pre-retile frames.
            if deferredCommandZOrderRestore {
                deferredCommandZOrderRestore = false
                scheduleZOrderRestore()
            }
        }
        return response
    }

    /// The scalar layout parameters that only re-divide room
    /// among the windows already placed, so their retile may
    /// slide a shrinking pane's shared edge instead of snapping
    /// it (#593). Named one by one rather than derived from a
    /// prefix or a `set_`/`ratio` pattern: this whole dispatch
    /// shares ONE trailing retile, and its other members —
    /// `stack.set_master_count`, `stack.set_stack_position`,
    /// `track.set_limit`, `grid.set_dimensions`, every
    /// `set_new_window_placement` — reassign slots wholesale and
    /// must keep the #45 snap.
    ///
    /// A command that gets renamed out of this set falls back to
    /// `.reflow`, which is the fail-safe direction: a lost snap is
    /// cosmetic, a lost reflow is a visible overlap.
    private static let resizeLikeCommands: Set<String> = [
        "bsp.set_ratio_h",
        "bsp.set_ratio_v",
        "stack.set_master_ratio",
        "scroll.set_slot_size",
    ]

    private static func sizeIntent(
        for command: String
    ) -> SizeIntent {
        resizeLikeCommands.contains(command) ? .resize : .reflow
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
