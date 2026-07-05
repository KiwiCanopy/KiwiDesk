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
            guard let raw = args.first?.stringValue,
                let orientation =
                    MonocleParams.Orientation(rawValue: raw)
            else {
                return .fail("expected horizontal|vertical")
            }
            tiler.settings.monocle.orientation = orientation
            warnOnMonocleBarMismatch()
            return .ok()
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
