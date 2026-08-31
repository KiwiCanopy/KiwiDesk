import KiwiDeskCore

/// Monitor layout model extension for `SettingsModel` (#678 turn 13b).
extension SettingsModel {
    /// Computes resolved screen placement for all spaces (`SpacePlacement`,
    /// #53, `ProfileComposition`).
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
    /// #678 turn 13b).
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
