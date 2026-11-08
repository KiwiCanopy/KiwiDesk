import Foundation

/// The tiling toggle (#3008): `toggle_tiling` and `set_tiling` turn
/// a Space's tiling off and on for the session, and the two named
/// stand-downs read the profile's ticks. The Space's windows stay
/// where they are; resuming lays its array out again.
extension KiwiCore {
    /// Mirrors the config's start-tiled values into state: the one
    /// writer, called where its inputs change — `tiler.settings`'
    /// `tiling` group and `appWideLiveChanged`.
    func mirrorTilingStart() {
        let next = tiler.settings.tiling.start(
            global: appWide.tilingStartGlobal
        )
        seedSlotsBeforeTilingOff(
            state.workspaces.allSpaces.map(\.id).filter {
                state.tilingToggles[$0] == nil && !next.startsTiled($0)
            }
        )
        state.tilingStart = next
    }

    /// Seeds each hidden Space about to lose its tiling a capture at
    /// the slots its layout draws, so the stash brings its windows
    /// back from the park when it shows (#3008). Runs while the
    /// Space still tiles; a shown Space's windows are on screen.
    func seedSlotsBeforeTilingOff(_ spaces: [SpaceID]) {
        let visible = state.workspaces.visibleSpaces
        for id in spaces where !visible.contains(id) {
            guard !state.isTilingOff(id),
                let space = state.workspaces[id],
                let screen = TilingEngine.screen(for: id, in: state)
            else { continue }
            let frames = tiler.placedFrames(
                of: space,
                on: screen,
                state: state
            ).frames
            for (window, frame) in frames
            where tiler.stashOriginal(window) == nil {
                tiler.seedStash(window, frame: frame)
            }
        }
    }

    /// Whether `space` has tiling off now.
    public func isTilingOff(_ space: SpaceID) -> Bool {
        state.isTilingOff(space)
    }

    /// `KiwiDesk.toggle_tiling([space])`: flips the Space's tiling,
    /// the active Space's when none is named.
    func toggleTilingCommand(_ args: [JSONValue]) -> CommandResponse {
        guard let space = tilingSpace(args.first) else {
            return .fail("unknown space")
        }
        return setTiling(isTilingOff(space), on: space)
    }

    /// `KiwiDesk.set_tiling(on[, space])`: turns the Space's tiling
    /// on or off without reading it first.
    func setTilingCommand(_ args: [JSONValue]) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        guard let space = tilingSpace(args.dropFirst().first) else {
            return .fail("unknown space")
        }
        return setTiling(on, on: space)
    }

    /// The Space `arg` names, or the active one when it names none.
    private func tilingSpace(_ arg: JSONValue?) -> SpaceID? {
        guard let raw = arg?.stringValue else {
            return state.workspaces.activeSpace
        }
        let id = SpaceID(raw)
        return state.workspaces[id] == nil ? nil : id
    }

    /// Records the choice and lays the Space out under it: a resume
    /// is an explicit apply (AGENTS.md §5), a stop moves nothing.
    private func setTiling(
        _ tiling: Bool,
        on space: SpaceID
    ) -> CommandResponse {
        if !tiling { seedSlotsBeforeTilingOff([space]) }
        state.setTiling(tiling, for: space)
        retile(pass: tiling ? .apply : .event)
        return .ok()
    }

    /// `KiwiDesk.set_tiling_start_global(bool)`: app-wide (#1741)
    /// and session-only, as every app-wide verb.
    func setTilingStartGlobal(_ args: [JSONValue]) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        setAppWide(persisting: false) { $0.tilingStartGlobal = on }
        retile(pass: .apply)
        return .ok()
    }

    /// The `tiling.*` setters; the dispatch retiles after them.
    func tilingSettingsCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "tiling.set_start":
            let first = args.first ?? .null
            let on = first.boolValue
            guard on != nil || first == .null else {
                return .fail("expected a boolean or nil")
            }
            guard let raw = args.dropFirst().first?.stringValue else {
                tiler.settings.tiling.start = on
                return .ok()
            }
            tiler.settings.tiling.startOverride[SpaceID(raw)] = on
        case "tiling.set_off_hides_borders":
            guard let on = args.first?.boolValue else {
                return .fail("expected a boolean")
            }
            tiler.settings.tiling.offHidesBorders = on
        case "tiling.set_off_hides_bars":
            guard let on = args.first?.boolValue else {
                return .fail("expected a boolean")
            }
            tiler.settings.tiling.offHidesBars = on
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
    }

    /// Whether the Space `display` shows has tiling off and the
    /// profile hides the bars for it — `shelfStandsDown`'s one
    /// tiling-off read (bars.md).
    func tilingOffHidesShelf(on display: DisplayID) -> Bool {
        guard tiler.settings.tiling.offHidesBars,
            let space = state.workspaces.activeSpace(on: display)
        else { return false }
        return isTilingOff(space)
    }

    /// Whether the active Space has tiling off and the profile hides
    /// its rings — `desiredBorderSpecs`' one tiling-off read
    /// (borders.md).
    func tilingOffHidesRings(on space: SpaceID) -> Bool {
        tiler.settings.tiling.offHidesBorders && isTilingOff(space)
    }
}
