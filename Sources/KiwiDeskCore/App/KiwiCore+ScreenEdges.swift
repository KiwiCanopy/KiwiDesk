import Foundation

/// A bar's and the pocket's edge per screen (#1948, #3376): which
/// screen a display is to the per-screen maps, which screens a
/// write judges, and how `set_edge`'s and `set_pocket_edge`'s
/// optional screen argument names one.
extension KiwiCore {
    /// The fingerprint `display`'s bar and pocket edges resolve
    /// under — the key `space_bar.edge_override`,
    /// `app_bar.edge_override` and `kiwishelf.pocket_edge_override`
    /// are stored by — or nil for a display no longer connected. The
    /// ONE screen identity: the engine's `screenFingerprint` seam
    /// is wired to it in `bootstrapCoreServices`.
    func screenFingerprint(of display: DisplayID) -> String? {
        state.workspaces.allDisplays.first { $0.id == display }?
            .fingerprint
    }

    /// The live settings as `display` shows them: each bar's edge
    /// resolved for that screen (`TilingSettings.onScreen(_:)`).
    /// What the bars SHOW there is `shelfSettings(on:)`'s.
    func settings(on display: DisplayID) -> TilingSettings {
        tiler.settings.onScreen(screenFingerprint(of: display))
    }

    /// The shelf as `display` shows it: the pocket's edge resolved
    /// for that screen (#3376). The pocket's readers of a display's
    /// edge take this, or `settings(on:)`, never
    /// `tiler.settings.kiwishelf.pocketEdge`
    /// (`PocketEdgeCensusTests`). It answers the edge and the look
    /// only: what the screen shows — its Pocket's visibility — is
    /// `shelfSettings(on:)`'s.
    func shelf(on display: DisplayID) -> KiwiShelf {
        tiler.settings.kiwishelf.onScreen(screenFingerprint(of: display))
    }

    /// The settings `display`'s shelf reads: each bar's edge as
    /// that screen has it, and every bar and the Pocket Hidden on a
    /// tiling-off Space whose tick hides the bars (#3151) or where
    /// the screen shows a maximized window (#3346), so a shortcut
    /// still shows one. The one door a reader of a screen's bar or
    /// Pocket visibility takes (`TilingOffBarsHiddenSeamTests`).
    func shelfSettings(on display: DisplayID) -> TilingSettings {
        let shown = settings(on: display)
        return tilingOffHidesShelf(on: display)
            || screenMaximizes(on: display)
            ? shown.hidingEveryBar() : shown
    }

    /// Whether `display` shows a maximized window: a Maximize over
    /// the shelf (`showsMaximized`, the command, a Height or Width
    /// reaching a strip, KiwiVision's fill) or a Monocle that
    /// maximizes its windows (#2976). The one "maximized here"
    /// predicate the shelf, its bands and the overflow marks ask
    /// (#3346).
    func screenMaximizes(on display: DisplayID) -> Bool {
        showsMaximized(on: display)
            || settings(on: display).maximizesWindows(
                in: shownMode(on: display)
            )
    }

    /// The bars resting at their edge brings in over the window
    /// `display` shows maximized — by the command, a Height or
    /// Width reaching the shelf, KiwiVision, or Monocle's "Maximize
    /// windows" (#3346) — read off the stored bars through
    /// `TilingSettings.maximizedHoverBars(in:)`.
    func maximizedHoverBars(on display: DisplayID) -> Set<ShelfBar> {
        maximizedStored(on: display).map {
            $0.settings.maximizedHoverBars(in: $0.mode)
        } ?? []
    }

    /// Whether `display`'s Pocket comes in with a bar revealed over
    /// its maximized window (#3346 ▸ 8).
    func maximizedPocketRides(on display: DisplayID) -> Bool {
        maximizedStored(on: display)?.settings.maximizedPocketRides
            == true
    }

    /// The stored settings and layout of a screen showing a
    /// maximized window, nil elsewhere and where the tiling-off tick
    /// hides the bars, which asks for Hidden.
    private func maximizedStored(
        on display: DisplayID
    ) -> (settings: TilingSettings, mode: LayoutMode)? {
        guard !tilingOffHidesShelf(on: display),
            screenMaximizes(on: display)
        else { return nil }
        return (settings(on: display), shownMode(on: display))
    }

    /// The axis a Space switch's plates slide along on `display`:
    /// across the Space Bar's edge as that screen has it (#1956,
    /// #1948).
    func spaceSlideAxis(on display: DisplayID) -> SpaceSlidePlan.Axis {
        SpaceSlidePlan.axis(
            spaceBarEdge: settings(on: display).spaceBarStyle.edge
        )
    }

    /// Every layout's layout-bounds input on every connected
    /// screen, and with no screen (the bars' own edges) — read
    /// through the one `shelfReservation(in:on:pocketAtRest:)` `layoutBounds`
    /// reads, so a bar write that moves one screen's strip owes
    /// the pass (#1524, #1948).
    var shelfReservations: [ShelfReservation] {
        // The bounds' own read, so the skip and the bounds agree.
        let pocketAtRest = tiler.settings.pocketRests
        let screens: [String?] =
            [nil] + state.workspaces.allDisplays.map(\.fingerprint)
        return screens.flatMap { screen in
            LayoutMode.allCases.map {
                tiler.settings.shelfReservation(
                    in: $0,
                    on: screen,
                    pocketAtRest: pocketAtRest
                )
            }
        }
    }

    /// The ONE scope a per-screen edge write judges its collapse
    /// over (`ScreenEdged.setEdge(_:on:among:)`): the screens of
    /// `monitorSets` and the connected ones — the write adds the
    /// entries' own. A writer hands it the monitor sets of the
    /// profile it writes: the verb the live profile's
    /// (`liveScreenEdgeScope`), a Settings writer its draft's,
    /// never an empty list in their place.
    public func screenEdgeScope(
        monitorSets: [MonitorSet]
    ) -> ScreenEdgeScope {
        ScreenEdgeScope(
            screens: Set(monitorSets.flatMap(\.monitors)).union(
                connectedDisplays().map(\.fingerprint)
            )
        )
    }

    /// The scope for a write of the live settings: the adopted
    /// profile's monitor sets, which follow every write of its
    /// file (`ActiveProfile.refiled(_:)`).
    var liveScreenEdgeScope: ScreenEdgeScope {
        screenEdgeScope(
            monitorSets: profiles.active?.monitorSets ?? []
        )
    }

    /// `screenField`'s arguments — a bar's `edge` (#1948), the
    /// shelf's `pocket_edge` (#3376) — with the optional screen resolved
    /// to the fingerprint it is stored under, the edge checked
    /// first so a bad edge answers as one: a connected screen by
    /// number, fingerprint or name, as `pin_space_to_display`
    /// names one — the `NSScreen` list standing in before the
    /// first display is published, so `init.lua` names a screen
    /// at boot — else a `Name:WxH` fingerprint stored as given,
    /// a screen that is not connected. Other fields pass through.
    func screenResolvedEdgeArgs(
        field: String,
        screenField: String,
        _ args: [JSONValue]
    ) -> Result<[JSONValue], AppBarSettingError> {
        guard field == screenField, args.count > 1 else {
            return .success(args)
        }
        if case .failure(let error) = BarSettingChoice.value(
            args,
            AppBarEdge.self
        ) {
            return .failure(error)
        }
        let displays = connectedDisplays()
        let screen: String
        if let id = resolveDisplayArg(args[1], among: displays),
            let found = displays.first(where: { $0.id == id })
        {
            screen = found.fingerprint
        } else if let raw = args[1].stringValue,
            Self.isFingerprint(raw)
        {
            screen = raw
        } else {
            return .failure(
                AppBarSettingError(stringLiteral: Self.unknownScreen)
            )
        }
        var resolved = args
        resolved[1] = .string(screen)
        return .success(resolved)
    }

    /// The refusal of a screen argument that names no screen.
    static let unknownScreen =
        "expected a screen number, fingerprint or name"

    /// Whether `raw` is shaped like a `Display.fingerprint`: a
    /// name, then a positive `WxH`.
    static func isFingerprint(_ raw: String) -> Bool {
        let parts = Display.fingerprintParts(raw)
        let size = parts.size.split(separator: "x")
        return !parts.name.isEmpty && size.count == 2
            && size.allSatisfy { (Int($0) ?? 0) > 0 }
    }
}
