import KiwiDeskCore

/// Monitor layout model extension for `SettingsModel` (#678 turn 13b).
extension SettingsModel {
    /// Computes resolved placement for ALL spaces in one
    /// composition pass (#53, `SpacePlacement`): per-space calls
    /// re-composed the whole profile per card — quadratic exactly
    /// where this surface is most alive. One divergence from the
    /// runtime: a pin to a disconnected monitor renders as pinned
    /// (the user's intent), while the runtime places the space on
    /// the fallback display.
    func resolutions() -> [SpaceID: SpaceResolution] {
        let mainID = PositionalDisplays.liveMainID
        let assignment =
            ProfileComposition.compose(
                displays: displays,
                mainID: mainID
            )?.assignment ?? [:]
        var resolved: [SpaceID: SpaceResolution] = [:]
        for space in config.spaces {
            resolved[space] = Self.reading(
                SpacePlacement.resolve(
                    space: space,
                    pins: config.spacePins,
                    mainSpaces: config.mainSpaces,
                    displays: displays,
                    mainID: mainID,
                    assignment: assignment
                )
            )
        }
        return resolved
    }

    /// Monitors area row expansion model (`MonitorsFamilyRows`,
    /// #678 turn 13b). Frames are read LIVE off Core, never
    /// snapshotted onto the model: `SettingsWindowController`
    /// republishes on a display change, and a cached arrangement
    /// is what would go stale behind it.
    var monitorRows: MonitorsFamilyRows {
        MonitorsFamilyRows(
            spaces: config.spaces,
            mainSpaces: config.mainSpaces,
            resolutions: resolutions(),
            pins: config.spacePins,
            displays: displays
        )
    }

    /// Converts `SpacePlacement.Resolution` into display `SpaceResolution`.
    private static func reading(
        _ resolved: SpacePlacement.Resolution?
    ) -> SpaceResolution {
        switch resolved {
        case .pinned(let display):
            return .pinned(display.fingerprint)
        case .pinnedAbsent(intent: let pin, fallback: _):
            return .pinned(pin)
        case .main:
            return .main
        case .auto(let display):
            return .auto(display.fingerprint)
        case nil:
            return .auto(nil)
        }
    }

    /// Returns active space displayed on given screen.
    func showingSpace(on display: DisplayID) -> SpaceID? {
        core.state.workspaces.activeSpace(on: display)
    }

    /// Resolves human-readable monitor name from fingerprint.
    func monitorName(_ fingerprint: String) -> String {
        displays.first {
            $0.fingerprint == fingerprint
        }?.name ?? fingerprint
    }

    /// Active main display (`PositionalDisplays.liveMainID`).
    /// ONE derivation, because the picture reads it twice — the
    /// tray and the "main" badge; a second derivation by
    /// fingerprint produced two answers on a twin-monitor desk.
    var mainDisplay: Display? {
        let mainID = PositionalDisplays.liveMainID
        return displays.first { $0.id == mainID }
            ?? PositionalDisplays.ordered(
                displays,
                mainID: mainID
            ).first
    }
}

/// Space screen resolution state (#36, #53).
enum SpaceResolution: Equatable {
    case pinned(String)
    case main
    case auto(String?)
}
