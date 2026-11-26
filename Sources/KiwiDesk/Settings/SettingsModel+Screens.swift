import CoreGraphics
import Foundation
import KiwiDeskCore

/// Screen layout model extension for `SettingsModel` (#678 turn 13b).
extension SettingsModel {
    /// Computes resolved placement for ALL spaces in one
    /// composition pass (#53, `SpacePlacement`): per-space calls
    /// re-composed the whole profile per card — quadratic exactly
    /// where this surface is most alive. One divergence from the
    /// runtime: a pin to a disconnected screen renders as pinned
    /// (the user's intent), while the runtime places the space on
    /// the fallback screen.
    func resolutions() -> [SpaceID: SpaceResolution] {
        let mainID = PositionalDisplays.liveMainID
        let assignment = placementAssignment()
        var resolved: [SpaceID: SpaceResolution] = [:]
        for space in config.spaces {
            resolved[space] = reading(
                SpacePlacement.resolve(
                    space: space,
                    pins: resolvedPins,
                    mainSpaces: config.mainSpaces,
                    displays: displays,
                    mainID: mainID,
                    assignment: assignment
                ),
                pin: pin(of: space)
            )
        }
        return resolved
    }

    /// The positional plan both placement readers hand
    /// `SpacePlacement.resolve`: the Screens picture's and Simple's
    /// preview (#2737), so the two read one plan.
    func placementAssignment() -> [SpaceID: DisplayID] {
        SpacePlacement.numberedPlan(
            displays: displays,
            mainID: PositionalDisplays.liveMainID
        )
    }

    /// Screens area row expansion model (`ScreensFamilyRows`,
    /// #678 turn 13b). Frames are read LIVE off Core, never
    /// snapshotted onto the model: `SettingsWindowController`
    /// republishes on a screen change, and a cached arrangement
    /// is what would go stale behind it.
    var screenRows: ScreensFamilyRows {
        ScreensFamilyRows(
            spaces: config.spaces,
            mainSpaces: config.mainSpaces,
            resolutions: resolutions(),
            pins: resolvedPins,
            displays: displays,
            splits: config.settings.displayAreas,
            waiting: waitingPins
        )
    }

    /// Converts `SpacePlacement.Resolution` into the view
    /// `SpaceResolution`. A pin to a connected screen keeps its area
    /// key while the draft's split holds that area, else its screen's
    /// area 0, as the runtime's one resolver falls back (#3517 ruling
    /// 22); every other placement lands in area 0.
    private func reading(
        _ resolved: SpacePlacement.Resolution?,
        pin: String?
    ) -> SpaceResolution {
        switch resolved {
        case .pinned(let display):
            // The pin's own key, its area gone → area 0 (ruling 22).
            return .pinned(resolvedPin(pin ?? display.fingerprint))
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

    /// The Space the area `key` names shows on `display` (#3517),
    /// its screen's where the key names no live area.
    func showingSpace(inArea key: String, on display: DisplayID) -> SpaceID? {
        let workspaces = core.state.workspaces
        guard
            let area = workspaces.placement(
                keyed: ScreenAreaKey(parsing: key),
                on: display
            )
        else { return workspaces.activeSpace(on: display) }
        return workspaces.activeSpace(on: area)
    }

    /// Resolves human-readable screen name from fingerprint.
    func screenName(_ fingerprint: String) -> String {
        displays.first {
            $0.fingerprint == fingerprint
        }?.name ?? fingerprint
    }

    /// The one connected screen `matches` picks out, in copy's
    /// words (a twin by its position, #3502); nil where none or
    /// more than one does, which a caller words its own way. A
    /// stored name stays macOS's; only the words move.
    func screenWords(where matches: (Display) -> Bool) -> String? {
        let found = displays.filter(matches)
        return found.count == 1 ? found.first.map(screenLabel) : nil
    }

    /// A screen by the name macOS gives it, in copy's words where
    /// exactly one connected screen carries the name.
    func screenWords(named name: String) -> String {
        screenWords { $0.name == name } ?? name
    }

    /// Active main screen (`PositionalDisplays.liveMainID`).
    /// ONE derivation, because the picture reads it twice — the
    /// tray and the "main" badge; a second derivation by
    /// fingerprint produced two answers on a twin-screen desk.
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
