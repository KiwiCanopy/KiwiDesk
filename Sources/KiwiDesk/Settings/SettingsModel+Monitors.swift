import KiwiDeskCore

/// The dashboard model's Monitors half (#678 turn 13b split from
/// `SettingsModel+Profiles.swift` on the file ceiling): where
/// each space resolves, which display is main, and what the
/// picture's row expansion is built from.
///
/// The seam is the SUBJECT, not the surface: this owns display
/// identity and space→display placement, which several pages ask
/// about — the Spaces pin badge and a profile row's subtitle both
/// read `monitorName(_:)`. Profiles owns saving and loading. Both
/// are extensions on the one model, whose stored `@Published`
/// properties stay on the class.
extension SettingsModel {
    // MARK: - Space placement (Canvas)

    /// Where each space renders in the picture, via the same
    /// `SpacePlacement` precedence the runtime resolves with
    /// (pin → Main → positional default). There is no
    /// "unassigned" state — defaults compose a concrete
    /// layout (#53). One conscious divergence: a pin to a
    /// disconnected monitor renders as pinned (the user's
    /// intent), while the runtime places the space on the
    /// fallback display until that monitor returns.
    ///
    /// Every declared space in ONE composition pass (#678 turn
    /// 13b). It used to be a per-space call, and the picture asks
    /// about every space once per card, so each card re-composed
    /// the whole profile — quadratic in exactly the displays ×
    /// spaces this surface is most alive at.
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

    /// The Monitors area's row expansion, built from live state —
    /// what the cards, the tray, the orphan card and the
    /// fingerprint drawer all draw from, and what the census
    /// guards read (#678 turn 13b).
    ///
    /// Built here rather than in each view so both halves of the
    /// seam answer from one construction; the frames themselves
    /// are read LIVE off Core, never snapshotted onto the model,
    /// because `SettingsWindowController` republishes on a
    /// display change and a cached arrangement is the thing that
    /// would go stale behind it.
    var monitorRows: MonitorsFamilyRows {
        MonitorsFamilyRows(
            spaces: config.spaces,
            mainSpaces: config.mainSpaces,
            resolutions: resolutions(),
            pins: config.spacePins,
            displays: displays
        )
    }

    /// The picture's reading of one `SpacePlacement` verdict.
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

    /// The space currently on a display, for the picture's
    /// selection readout — the one thing the arrangement cannot
    /// show, since a card draws where spaces LIVE rather than
    /// which of them is up.
    func showingSpace(on display: DisplayID) -> SpaceID? {
        core.state.workspaces.activeSpace(on: display)
    }

    /// Human-readable monitor name, falling back to the raw
    /// fingerprint when that display isn't connected — read by
    /// the Spaces pin badge and a profile row's subtitle. The
    /// Monitors picture names displays from the `Display` values
    /// it already holds.
    func monitorName(_ fingerprint: String) -> String {
        displays.first {
            $0.fingerprint == fingerprint
        }?.name ?? fingerprint
    }

    /// The current main display, falling back positionally
    /// (leftmost) exactly as the runtime does. ONE derivation,
    /// because the picture reads it twice: the follows-main tray
    /// hangs off this display and the "main" badge marks it, and
    /// a badge on one card beside a tray under another would be
    /// two answers to one question — which is exactly what a
    /// second derivation by fingerprint produced on a twin-monitor
    /// desk.
    var mainDisplay: Display? {
        let mainID = PositionalDisplays.liveMainID
        return displays.first { $0.id == mainID }
            ?? PositionalDisplays.ordered(
                displays,
                mainID: mainID
            ).first
    }

    /// The current main display's fingerprint, for the callers
    /// that key off identity strings rather than ids.
    var mainFingerprint: String? {
        mainDisplay?.fingerprint
    }
}

/// How a space's screen resolves in the picture (#36).
enum SpaceResolution: Equatable {
    case pinned(String)
    case main
    /// Auto-assigned by the positional default (#53).
    case auto(String?)
}
