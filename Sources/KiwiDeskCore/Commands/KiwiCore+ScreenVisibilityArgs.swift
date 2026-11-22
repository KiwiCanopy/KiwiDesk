import Foundation

/// A bar verb's screen argument (#1948, #3517): `set_edge` names a
/// physical screen, stored by fingerprint; `set_visibility` names a
/// screen or one of its areas, stored by `ScreenAreaKey`.
extension KiwiCore {
    /// `args` with the verb's screen resolved: `set_edge`'s through
    /// `screenResolvedEdgeArgs`, `set_visibility`'s to an area key.
    func screenResolvedBarArgs(
        field: String,
        _ args: [JSONValue]
    ) -> Result<[JSONValue], AppBarSettingError> {
        guard field == "visibility" else {
            return screenResolvedEdgeArgs(
                field: field,
                screenField: "edge",
                args
            )
        }
        guard args.count > 1 else { return .success(args) }
        if case .failure(let error) = BarSettingChoice.value(
            args,
            ShelfVisibility.self
        ) {
            return .failure(error)
        }
        guard let key = areaKey(named: args[1]) else {
            return .failure(
                AppBarSettingError(stringLiteral: Self.unknownArea)
            )
        }
        var resolved = args
        resolved[1] = .string(key)
        return .success(resolved)
    }

    /// The stored key a screen-or-area argument names, in ruling
    /// 16's order: a number names a physical screen, as Desktop
    /// bindings count them, its lead area keyed by the bare
    /// fingerprint; then a fingerprint or an area key — on a
    /// connected screen through the one `placement(keyed:on:)`, so
    /// an area that is gone falls back to the screen's lead area
    /// (ruling 22), and stored as given for a screen not connected;
    /// then a screen's name; then an area's own name, refused where
    /// two share it.
    func areaKey(named arg: JSONValue) -> String? {
        let displays = connectedDisplays()
        let fingerprint = { (id: DisplayID) in
            displays.first { $0.id == id }?.fingerprint
        }
        if arg.intValue != nil {
            return resolveDisplayArg(arg, among: displays)
                .flatMap(fingerprint)
        }
        guard let raw = arg.stringValue else { return nil }
        let key = ScreenAreaKey(parsing: raw)
        if Self.isFingerprint(key.fingerprint) {
            let ws = state.workspaces
            guard
                let screen = ws.allDisplays.first(where: {
                    $0.fingerprint == key.fingerprint
                })
            else { return key.description }
            return ws.placement(keyed: key, on: screen.id)
                .flatMap { ws[placement: $0]?.key.description }
                ?? key.fingerprint
        }
        if let id = resolveDisplayArg(arg, among: displays) {
            return fingerprint(id)
        }
        let named = state.workspaces.allPlacements.filter {
            $0.area.name == raw
        }
        return named.count == 1 ? named[0].key.description : nil
    }

    /// The refusal of a screen argument that names no screen or
    /// area.
    static let unknownArea =
        "expected a screen number, fingerprint, area key or name"

    /// The refusal of a layout's per-screen App Bar visibility,
    /// which is global.
    static let appBarScreenVisibilityIsGlobal =
        "the App Bar's per-screen visibility is global: "
        + "app_bar.set_visibility"

    /// The refusal of an App Bar visibility for no screen: each
    /// layout holds its own.
    static let appBarVisibilityNeedsAScreen =
        "app_bar.set_visibility takes a screen; a layout's own App "
        + "Bar visibility is <layout>.set_app_bar_visibility"
}
