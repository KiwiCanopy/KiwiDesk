import Foundation

/// A bar's edge per screen (#1948): which screen a display is to
/// the per-screen map, and how `set_edge`'s optional screen
/// argument names one.
extension KiwiCore {
    /// The fingerprint `display`'s bar edges resolve under — the
    /// key `space_bar.edge_override` / `app_bar.edge_override` is
    /// stored by — or nil for a display no longer connected.
    func screenFingerprint(of display: DisplayID) -> String? {
        state.workspaces.allDisplays.first { $0.id == display }?
            .fingerprint
    }

    /// The live settings as `display` shows them: each bar's edge
    /// resolved for that screen (`TilingSettings.onScreen(_:)`).
    func settings(on display: DisplayID) -> TilingSettings {
        tiler.settings.onScreen(screenFingerprint(of: display))
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

    /// `set_edge`'s arguments with the optional screen resolved
    /// to the fingerprint it is stored under: a connected screen
    /// by number, fingerprint or name, as `pin_space_to_display`
    /// names one, else a `Name:WxH` fingerprint stored as given,
    /// so a config may name a screen that is not connected. Nil
    /// when the screen argument names none.
    func screenResolvedEdgeArgs(_ args: [JSONValue]) -> [JSONValue]? {
        guard args.count > 1 else { return args }
        let screen: String
        if let display = resolveDisplayArg(args[1]),
            let connected = screenFingerprint(of: display)
        {
            screen = connected
        } else if let raw = args[1].stringValue,
            Self.isFingerprint(raw)
        {
            screen = raw
        } else {
            return nil
        }
        var resolved = args
        resolved[1] = .string(screen)
        return resolved
    }

    /// The refusal of a screen argument that names no screen.
    static let unknownScreen =
        "expected a screen number, fingerprint or name"

    /// Whether `raw` is shaped like a `Display.fingerprint`.
    static func isFingerprint(_ raw: String) -> Bool {
        let parts = Display.fingerprintParts(raw)
        let size = parts.size.split(separator: "x")
        return !parts.name.isEmpty && size.count == 2
            && size.allSatisfy { Int($0) != nil }
    }

    /// The connected screens' fingerprints — the screens a
    /// screened `set_edge` collapses over (`ScreenEdged`).
    var connectedScreens: Set<String> {
        Set(state.workspaces.allDisplays.map(\.fingerprint))
    }
}
