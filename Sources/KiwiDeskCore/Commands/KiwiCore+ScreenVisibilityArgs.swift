import Foundation

/// A bar verb's screen argument (#1948, #3517 rulings 16, 22): it
/// names a physical screen, which writes every area of it, or one
/// area, written alone; reads are exact, so the fan-out is the
/// write's (bars.md).
extension KiwiCore {
    /// `args` once per key the verb's screen names: `set_edge`'s
    /// through `screenResolvedEdgeArgs`, `set_visibility`'s here.
    /// A call with no screen is itself, once. A screen named by
    /// number or name while none is known holds the call, which
    /// `replay` makes again at the first report, and answers no
    /// calls now (#3640).
    func screenResolvedBarArgs(
        field: String,
        _ args: [JSONValue],
        replay: @escaping @MainActor () -> CommandResponse
    ) -> Result<[[JSONValue]], AppBarSettingError> {
        guard field == "visibility" else {
            return screenResolvedEdgeArgs(
                field: field,
                screenField: "edge",
                args,
                replay: replay
            )
        }
        guard args.count > 1 else { return .success([args]) }
        if case .failure(let error) = BarSettingChoice.value(
            args,
            ShelfVisibility.self
        ) {
            return .failure(error)
        }
        if holdsNumberedScreenArg(args[1]) {
            holdSettingsCall(split: false, replay: replay)
            return .success([])
        }
        guard let keys = areaKeys(named: args[1]), !keys.isEmpty else {
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

    /// The stored keys — `N` or `N#id` (#3647 ▸ lane 3c) — a
    /// screen-or-area argument names, in ruling 16's order. A
    /// physical screen — a number, or a connected screen's name —
    /// names every area it lays out in; a number no screen holds
    /// names itself, stored at once. A fingerprint or an area key
    /// names that one key, in the live order on a connected screen
    /// through the one `placement(keyed:on:)`, so an area that is
    /// gone falls back to the screen's lead area (ruling 22), and in
    /// the live profile's first setup holding it for a screen not
    /// connected. Last, an area's own name, refused where two share
    /// it. An empty answer names a screen the live order does not
    /// number, which the caller refuses as unknown.
    func areaKeys(named arg: JSONValue) -> [String]? {
        let ws = state.workspaces
        let order = liveScreenOrder
        let slot = { (key: ScreenAreaKey) in self.barKey(of: key, order: order)
        }
        let screenKeys = { (id: DisplayID) -> [String] in
            let areas = ws.placements(of: id).map(\.key)
            guard !areas.isEmpty else {
                return self.screenSlot(of: id).map { [$0] } ?? []
            }
            return areas.compactMap(slot)
        }
        if let number = arg.intValue {
            if let screen = screen(numbered: number) {
                return screenKeys(screen.id)
            }
            return ScreenSlotKey(number: number).map { [$0.description] }
        }
        guard let raw = arg.stringValue else { return nil }
        if let numbered = ScreenSlotKey(parsing: raw) {
            guard let screen = screen(numbered: numbered.number) else {
                return [numbered.description]
            }
            guard numbered.areaID > 0, let (_, key) = numberedArea(raw)
            else { return screenKeys(screen.id) }
            return areaSlot(keyed: key, on: screen, slot).map { [$0] } ?? []
        }
        let key = ScreenAreaKey(parsing: raw)
        if Self.isFingerprint(key.fingerprint) {
            if let screen = ws.allDisplays.first(where: {
                $0.fingerprint == key.fingerprint
            }) {
                return areaSlot(keyed: key, on: screen, slot).map { [$0] }
                    ?? []
            }
            let set = profiles.active?.monitorSets.first {
                $0.monitors.contains(key.fingerprint)
            }
            return set?.order.slot(of: key).map { [$0.description] }
        }
        if let id = resolveDisplayArg(arg, among: ws.allDisplays) {
            return screenKeys(id)
        }
        let named = ws.allPlacements.filter { $0.area.name == raw }
        guard named.count == 1 else { return nil }
        return slot(named[0].key).map { [$0] } ?? []
    }

    /// The slot key of `key`'s area on `screen`, a numbered
    /// connected screen, read against the number's stored split so a
    /// call replayed before the placements are built finds it: the
    /// lead area's where the area is gone (ruling 22). Nil for a
    /// screen the live order does not number.
    private func areaSlot(
        keyed key: ScreenAreaKey,
        on screen: Display,
        _ slot: (ScreenAreaKey) -> String?
    ) -> String? {
        let lead = ScreenAreaKey(fingerprint: screen.fingerprint, areaID: 0)
        guard key.areaID > 0,
            let number = liveScreenOrder.number(of: screen.fingerprint),
            tiler.settings.displayAreas[number: number]?.areas
                .contains(where: { $0.id == key.areaID }) == true
        else { return slot(lead) }
        return slot(key)
    }

    /// The refusal of a screen argument that names no screen or
    /// area.
    static let unknownArea =
        "expected a screen number, fingerprint, area key or name"
}
