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
            warnOnMonocleBarMismatch()
            return .ok()
        }
        if command == "monocle.set_orientation_override" {
            return applyMonocleOverride(args)
        }
        guard command.hasPrefix("monocle.set_app_bar_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("monocle.set_app_bar_".count)
        )
        let response = applyBarOverride(
            field: field,
            args,
            into: &tiler.settings.monocle.appBar
        )
        if response.isSuccess, field == "position" {
            warnOnMonocleBarMismatch()
        }
        return response
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

    private func warnOnMonocleBarMismatch() {
        warnOnBarPositionMismatch(
            host: tiler.settings.monocle,
            layout: "monocle",
            orientation: tiler.settings.monocle.orientation
                .rawValue
        )
    }

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
        let horizontal =
            tiler.settings.monocle.orientation == .horizontal
        let step: Int
        switch direction {
        case .left where horizontal: step = -1
        case .right where horizontal: step = 1
        case .up where !horizontal: step = -1
        case .down where !horizontal: step = 1
        default: return nil
        }
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard let index = tiled.firstIndex(of: focused)
        else { return nil }
        guard tiled.count > 1 else { return .ok() }
        let target =
            tiled[
                (index + step + tiled.count) % tiled.count
            ]
        if swapping {
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            retile()
        } else {
            focusWindow(target)
        }
        return .ok()
    }
}
