import Foundation

/// A bar verb's screen argument (#1948, #3517 rulings 16, 22): it
/// names a physical screen, which writes every area of it, or one
/// area, written alone; reads are exact, so the fan-out is the
/// write's (bars.md).
extension KiwiCore {
    /// `args` once per key the verb's screen names: `set_edge`'s
    /// through `screenResolvedEdgeArgs`, `set_visibility`'s here.
    /// A call with no screen is itself, once.
    func screenResolvedBarArgs(
        field: String,
        _ args: [JSONValue]
    ) -> Result<[[JSONValue]], AppBarSettingError> {
        guard field == "visibility" else {
            return screenResolvedEdgeArgs(
                field: field,
                screenField: "edge",
                args
            )
        }
        guard args.count > 1 else { return .success([args]) }
        if case .failure(let error) = BarSettingChoice.value(
            args,
            ShelfVisibility.self
        ) {
            return .failure(error)
        }
        guard let keys = areaKeys(named: args[1]) else {
            return .failure(
                AppBarSettingError(stringLiteral: Self.unknownArea)
            )
        }
        return .success(keys.map { Self.args(args, screen: $0) })
    }

    /// `args` with its screen argument replaced by `key`.
    static func args(_ args: [JSONValue], screen key: String) -> [JSONValue] {
        var resolved = args
        resolved[1] = .string(key)
        return resolved
    }

    /// The stored keys a screen-or-area argument names, in ruling
    /// 16's order. A physical screen — a number, as Desktop bindings
    /// count them, or a connected screen's name — names every area
    /// it lays out in, its lead area keyed by the bare fingerprint.
    /// A fingerprint or an area key names that one key: on a
    /// connected screen through the one `placement(keyed:on:)`, so
    /// an area that is gone falls back to the screen's lead area
    /// (ruling 22), and as given for a screen not connected. Last,
    /// an area's own name, refused where two share it.
    func areaKeys(named arg: JSONValue) -> [String]? {
        let displays = connectedDisplays()
        let ws = state.workspaces
        let screenKeys = { (id: DisplayID) -> [String]? in
            guard
                let fingerprint = displays.first(where: { $0.id == id })?
                    .fingerprint
            else { return nil }
            let areas = ws.placements(of: id).map(\.key.description)
            return areas.isEmpty ? [fingerprint] : areas
        }
        if arg.intValue != nil {
            return resolveDisplayArg(arg, among: displays).flatMap(screenKeys)
        }
        guard let raw = arg.stringValue else { return nil }
        let key = ScreenAreaKey(parsing: raw)
        if Self.isFingerprint(key.fingerprint) {
            guard
                let screen = ws.allDisplays.first(where: {
                    $0.fingerprint == key.fingerprint
                })
            else { return [key.description] }
            return [
                ws.placement(keyed: key, on: screen.id)
                    .flatMap { ws[placement: $0]?.key.description }
                    ?? key.fingerprint
            ]
        }
        if let id = resolveDisplayArg(arg, among: displays) {
            return screenKeys(id)
        }
        let named = ws.allPlacements.filter { $0.area.name == raw }
        return named.count == 1 ? [named[0].key.description] : nil
    }

    /// The refusal of a screen argument that names no screen or
    /// area.
    static let unknownArea =
        "expected a screen number, fingerprint, area key or name"
}
