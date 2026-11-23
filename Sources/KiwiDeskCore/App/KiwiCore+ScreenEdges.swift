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

    /// The settings as one area has them (#3517): `settings(on:)`
    /// keyed by the area's `ScreenAreaKey`.
    func settings(on placement: PlacementID) -> TilingSettings {
        tiler.settings.onScreen(areaKey(of: placement))
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
    /// tiling-off Space whose tick hides the bars (#3151), so a
    /// shortcut still shows one; where the screen shows a maximized
    /// window every bar Hidden and the Pocket at
    /// `maximizedPocketVisibility` (#3346, #3523). The one door a
    /// reader of a screen's bar or Pocket visibility takes
    /// (`TilingOffBarsHiddenSeamTests`).
    func shelfSettings(on display: DisplayID) -> TilingSettings {
        shelfSettings(
            key: screenFingerprint(of: display),
            tilingOff: tilingOffHidesShelf(on: display),
            maximized: screenMaximizes(on: display)
        )
    }

    /// The settings one area's shelf reads (#3517 ruling 30):
    /// `shelfSettings(on:)` for an area, keyed by its
    /// `ScreenAreaKey` and the Space it shows, which a split
    /// screen's bars take. On an unsplit screen the two answer
    /// alike.
    func shelfSettings(on placement: PlacementID) -> TilingSettings {
        shelfSettings(
            key: areaKey(of: placement),
            tilingOff: tilingOffHidesShelf(on: placement),
            maximized: screenMaximizes(on: placement)
        )
    }

    /// Whether `placement` shows a maximized window, the area's
    /// `screenMaximizes(on:)`.
    func screenMaximizes(on placement: PlacementID) -> Bool {
        maximizes(
            key: areaKey(of: placement),
            shown: state.workspaces.activeSpace(on: placement),
            on: placement.display
        )
    }

    /// The bars a pointer at their edge brings in over the window
    /// `placement` shows maximized, the area's
    /// `maximizedHoverBars(on:)`.
    func maximizedHoverBars(on placement: PlacementID) -> Set<ShelfBar> {
        hoverBars(
            key: areaKey(of: placement),
            shown: state.workspaces.activeSpace(on: placement),
            hidden: tilingOffHidesShelf(on: placement),
            maximized: screenMaximizes(on: placement)
        )
    }

    /// The key `placement`'s bars resolve under: its area's stored
    /// key, else — a screen with no placement record yet — the
    /// screen's fingerprint, as `settings(on:)` reads it.
    func areaKey(of placement: PlacementID) -> String? {
        state.workspaces[placement: placement]?.key.description
            ?? screenFingerprint(of: placement.display)
    }

    /// Whether `display` shows a maximized window: a Maximize over
    /// the shelf (`showsMaximized`, the command, a Height or Width
    /// reaching a strip, KiwiVision's fill) or a Monocle that
    /// maximizes its windows (#2976). The one "maximized here"
    /// predicate the shelf, its bands and the overflow marks ask
    /// (#3346).
    func screenMaximizes(on display: DisplayID) -> Bool {
        maximizes(
            key: screenFingerprint(of: display),
            shown: state.workspaces.activeSpace(on: display),
            on: display
        )
    }

    /// The bars resting at their edge brings in over the window
    /// `display` shows maximized — by the command, a Height or
    /// Width reaching the shelf, KiwiVision, or Monocle's "Maximize
    /// windows" (#3346) — read off the stored bars through
    /// `TilingSettings.maximizedHoverBars(in:)`.
    func maximizedHoverBars(on display: DisplayID) -> Set<ShelfBar> {
        hoverBars(
            key: screenFingerprint(of: display),
            shown: state.workspaces.activeSpace(on: display),
            hidden: tilingOffHidesShelf(on: display),
            maximized: screenMaximizes(on: display)
        )
    }

    // The one body of each screen and area door above, handed the
    // key the settings resolve under and the door's own readings
    // of the Space it shows (#3151, #3346, #3517).

    private func shelfSettings(
        key: String?,
        tilingOff: Bool,
        maximized: Bool
    ) -> TilingSettings {
        let shown = tiler.settings.onScreen(key)
        if tilingOff { return shown.hidingEveryBar() }
        return maximized ? shown.hidingEveryBarForMaximize() : shown
    }

    private func maximizes(
        key: String?,
        shown space: SpaceID?,
        on display: DisplayID
    ) -> Bool {
        showsMaximized(space, on: display)
            || tiler.settings.onScreen(key)
                .maximizesWindows(in: shownMode(of: space))
    }

    private func hoverBars(
        key: String?,
        shown space: SpaceID?,
        hidden: Bool,
        maximized: Bool
    ) -> Set<ShelfBar> {
        guard !hidden, maximized else { return [] }
        return tiler.settings.onScreen(key)
            .maximizedHoverBars(in: shownMode(of: space))
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
        // Every area of a split screen too, its key what its bounds
        // resolve under; the Pocket rests in the lead area (#3517).
        let screens: [(key: String?, pocket: Bool)] =
            [(nil, true)]
            + state.workspaces.allDisplays.flatMap { display in
                let areas = state.workspaces.placements(of: display.id)
                let lead = state.workspaces.leadPlacement(of: display.id)
                return [(display.fingerprint, true)]
                    + areas.filter { $0.id != lead }.map {
                        ($0.key.description, false)
                    }
            }
        return screens.flatMap { screen in
            LayoutMode.allCases.map {
                tiler.settings.shelfReservation(
                    in: $0,
                    on: screen.key,
                    pocketAtRest: pocketAtRest && screen.pocket
                )
            }
        }
    }

    /// The ONE scope a per-screen edge write judges its collapse
    /// over (`ScreenEdged.setEdge(_:on:among:)`): the screens of
    /// `monitorSets` and the connected ones, each with every area
    /// `splits` gives it (#3517) — the write adds the entries' own.
    /// A writer hands it the monitor sets and splits of the profile
    /// it writes: the verb the live profile's
    /// (`liveScreenEdgeScope`), a Settings writer its draft's,
    /// never an empty list in their place.
    public func screenEdgeScope(
        monitorSets: [MonitorSet],
        splits: [String: ScreenSplit]
    ) -> ScreenEdgeScope {
        let screens = Set(monitorSets.flatMap(\.monitors)).union(
            connectedDisplays().map(\.fingerprint)
        )
        return ScreenEdgeScope(
            screens: screens.union(
                screens.flatMap {
                    ScreenSplit.areaKeys(of: $0, in: splits)
                }
            )
        )
    }

    /// The scope for a write of the live settings: the adopted
    /// profile's monitor sets, which follow every write of its
    /// file (`ActiveProfile.refiled(_:)`), and the live splits.
    var liveScreenEdgeScope: ScreenEdgeScope {
        screenEdgeScope(
            monitorSets: profiles.active?.monitorSets ?? [],
            splits: tiler.settings.displayAreas
        )
    }

    /// `screenField`'s arguments — a bar's `edge` (#1948), the
    /// shelf's `pocket_edge` (#3376) — once per key the optional
    /// screen names through the one `areaKeys(named:)` (#3517
    /// rulings 7, 16, 22), the edge checked first so a bad edge
    /// answers as one. Other fields, and a call with no screen,
    /// pass through once.
    func screenResolvedEdgeArgs(
        field: String,
        screenField: String,
        _ args: [JSONValue]
    ) -> Result<[[JSONValue]], AppBarSettingError> {
        guard field == screenField, args.count > 1 else {
            return .success([args])
        }
        if case .failure(let error) = BarSettingChoice.value(
            args,
            AppBarEdge.self
        ) {
            return .failure(error)
        }
        guard let keys = areaKeys(named: args[1]) else {
            return .failure(
                AppBarSettingError(stringLiteral: Self.unknownScreen)
            )
        }
        return .success(keys.map { Self.args(args, screen: $0) })
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
