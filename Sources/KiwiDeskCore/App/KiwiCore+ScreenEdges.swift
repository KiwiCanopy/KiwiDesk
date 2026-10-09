import Foundation

/// A bar's edge per screen (#1948): which screen a display is to
/// the per-screen map, which screens a write judges, and how
/// `set_edge`'s optional screen argument names one.
extension KiwiCore {
    /// The fingerprint `display`'s bar edges resolve under — the
    /// key `space_bar.edge_override` / `app_bar.edge_override` is
    /// stored by — or nil for a display no longer connected. The
    /// ONE screen identity: the engine's `screenFingerprint` seam
    /// is wired to it in `bootstrapCoreServices`.
    func screenFingerprint(of display: DisplayID) -> String? {
        state.workspaces.allDisplays.first { $0.id == display }?
            .fingerprint
    }

    /// The live settings as `display` shows them: each bar's edge
    /// resolved for that screen (`TilingSettings.onScreen(_:)`).
    func settings(on display: DisplayID) -> TilingSettings {
        tiler.settings.onScreen(screenFingerprint(of: display))
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
    /// through the one `shelfReservation(in:on:)` `layoutBounds`
    /// reads, so a bar write that moves one screen's strip owes
    /// the pass (#1524, #1948).
    var shelfReservations: [ShelfReservation] {
        let screens: [String?] =
            [nil] + state.workspaces.allDisplays.map(\.fingerprint)
        return screens.flatMap { screen in
            LayoutMode.allCases.map {
                tiler.settings.shelfReservation(in: $0, on: screen)
            }
        }
    }

    /// The ONE set a per-screen edge write judges its collapse
    /// over (`ScreenEdged.setEdge(_:on:among:)`): the live
    /// profile's monitor-set screens and the connected ones —
    /// the entries' own screens are added by the write. Settings
    /// hands the same door its draft's monitor set.
    var screenEdgeScope: Set<String> {
        let profile = profiles.active?.monitors ?? []
        return profile.union(starterDisplays().map(\.fingerprint))
    }

    /// `set_edge`'s arguments with the optional screen resolved
    /// to the fingerprint it is stored under, the edge checked
    /// first so a bad edge answers as one: a connected screen by
    /// number, fingerprint or name, as `pin_space_to_display`
    /// names one — the `NSScreen` list standing in before the
    /// first display is published, so `init.lua` names a screen
    /// at boot — else a `Name:WxH` fingerprint stored as given,
    /// a screen that is not connected. Other fields pass through.
    func screenResolvedEdgeArgs(
        field: String,
        _ args: [JSONValue]
    ) -> Result<[JSONValue], AppBarSettingError> {
        guard field == "edge", args.count > 1 else {
            return .success(args)
        }
        if case .failure(let error) = BarSettingChoice.value(
            args,
            AppBarEdge.self
        ) {
            return .failure(error)
        }
        let displays = starterDisplays()
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
