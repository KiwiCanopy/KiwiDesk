import Foundation

/// monocle.* sub-API: orientation (which focus axis cycles
/// through the windows) and its indicator-bar overrides. The
/// bar's look is global (`app_bar.set_*`); `monocle.set_app_bar_*` only
/// carries this layout's `enabled` and per-field overrides.
extension KiwiCore {
    func monocleCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command == "monocle.set_orientation" {
            guard
                let orientation = Self.parseMonocleOrientation(
                    args.first?.stringValue
                )
            else { return Self.orientationError }
            tiler.settings.monocle.orientation = orientation
            return .ok()
        }
        if command == "monocle.set_orientation_override" {
            return applyMonocleOverride(args)
        }
        if command == "monocle.set_wrap_focus" {
            guard let on = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.settings.monocle.wrapFocus = on
            return .ok()
        }
        if command == "monocle.set_new_window_placement" {
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.monocle.newWindowPlacement = placement
            return .ok()
        }
        guard command.hasPrefix("monocle.set_app_bar_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("monocle.set_app_bar_".count)
        )
        return applyBarOverride(
            field: field,
            args,
            into: &tiler.settings.monocle.appBar
        )
    }

    /// `monocle.set_orientation_override(space, value)` — the
    /// per-space sibling of the global orientation setter (#17).
    /// Parses the same value, writes it into that space's
    /// override, and clears the entry when it becomes empty. The
    /// bar edge re-resolves against the merged orientation via
    /// `resolvedMonocle(for:)`.
    private func applyMonocleOverride(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let space = args.first?.stringValue, !space.isEmpty
        else { return .fail("expected space id and value") }
        guard
            let orientation = Self.parseMonocleOrientation(
                args.dropFirst().first?.stringValue
            )
        else { return Self.orientationError }
        var over =
            tiler.settings.monocle.override[SpaceID(space)]
            ?? MonocleOverride()
        over.orientation = orientation
        tiler.settings.monocle.override[SpaceID(space)] =
            over.isEmpty ? nil : over
        return .ok()
    }

    /// Shared by the global setter and its per-space override.
    static func parseMonocleOrientation(
        _ raw: String?
    ) -> MonocleParams.Orientation? {
        raw.flatMap(MonocleParams.Orientation.init(rawValue:))
    }

    private static let orientationError = CommandResponse.fail(
        "expected horizontal|vertical"
    )

    /// Cycles or reorders along the monocle orientation axis.
    ///
    /// `focus`/`swap` in the orientation's directions step
    /// through the space's flat window order, wrapping at the
    /// ends. Nil for cross-axis directions and for a floating
    /// focused window — those keep the geometric navigation
    /// (which can still reach other monitors).
    func monocleCycle(
        _ direction: Direction,
        space: Space,
        focused: WindowID,
        swapping: Bool
    ) -> CommandResponse? {
        // Resolve per-space (#149): a space with a vertical
        // orientation override renders vertically, so its focus
        // cycle must gate on the same resolved axis the layout
        // and bar edge use — not the global setting. Mirrors
        // `scrollingStep`'s `resolvedScrolling(for:)`.
        let horizontal =
            tiler.settings.resolvedMonocle(for: space.id)
            .orientation == .horizontal
        let step: Int
        switch direction {
        case .left where horizontal: step = -1
        case .right where horizontal: step = 1
        case .up where !horizontal: step = -1
        case .down where !horizontal: step = 1
        default: return nil
        }
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        guard let index = tiled.firstIndex(of: focused)
        else { return nil }
        // A lone tiled window has nothing to cycle: fall
        // through instead of swallowing the press with `.ok()`,
        // so the float tier (#488) can answer — and with no
        // float that way the shared dead-end cue fires, like
        // every other layout's single-window edge.
        guard tiled.count > 1 else { return nil }
        let wrap =
            tiler.settings.resolvedMonocle(for: space.id)
            .wrapFocus
        let next = index + step
        let target: WindowID
        if tiled.indices.contains(next) {
            target = tiled[next]
        } else if !swapping, wrap {
            // Focus wraps the carousel (opt out with wrap_focus);
            // `swap` never wraps, matching scrolling/track (a
            // wrapping swap would teleport a window end to end).
            target = step > 0 ? tiled[0] : tiled[tiled.count - 1]
        } else {
            // At an end without a wrap: fall through. Every
            // monocle window shares one frame, so the TILED
            // search finds no neighbor; only the float tier
            // (#488) can answer — a deliberate float hop, never
            // an accidental tile jump — and with no float that
            // way the command cleanly fails.
            return nil
        }
        if swapping {
            if refuseSwapOntoTraveler(target, in: space) {
                return .ok()
            }
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            // Gate on `on_window_swap` like the geometric path and
            // `scrollingStep` (#149) — a bare `retile()` obeyed
            // `on_relayout` instead, so swap animations diverged
            // from every other swap.
            retile(
                animated: tiler.settings.animations.onWindowSwap
            )
        } else {
            focusWindow(target, warp: true)
        }
        return .ok()
    }
}
