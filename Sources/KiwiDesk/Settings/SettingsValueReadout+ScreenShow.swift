import KiwiDeskCore

/// A bar's per-screen and per-area edge and Show in the diff (#1948,
/// #3517 ruling 30), split from `SettingsValueReadout+KiwiShelf.swift`.
extension SettingsValueReadout {
    /// One row per screen or area whose Show changed, labelled with
    /// the bar's per-screen label and the key's screen, each side
    /// the value that screen shows: its own, else `own` — the Space
    /// Bar's own value — or Inherit for a layout's App Bar (#3618).
    static func screenShowRows(
        _ census: SettingKey,
        _ old: [String: ShelfVisibility],
        _ new: [String: ShelfVisibility],
        own: (old: ShelfVisibility, new: ShelfVisibility)?,
        splits: [String: ScreenSplit]
    ) -> [SettingsDiffRow] {
        let base = label(for: census)
        let name: (ShelfVisibility?) -> String = { value in
            guard let value else { return SettingsModel.inheritShow }
            return AppBarOptions.visibility.first { $0.0 == value }?.1 ?? ""
        }
        let before = { (key: String) in old[key] ?? own?.old }
        let after = { (key: String) in new[key] ?? own?.new }
        return Set(old.keys).union(new.keys)
            .filter { before($0) != after($0) }
            .sorted()
            .map { key in
                let area = ScreenAreaKey(parsing: key)
                let parts = Display.fingerprintParts(area.fingerprint)
                let screen = SettingsModel.perScreenName(
                    screen: "\(parts.name) \(parts.size)",
                    key: key,
                    splits: splits
                )
                return .change(
                    census,
                    instance: key,
                    label: instanceLabel(base, screen),
                    old: name(before(key)),
                    new: name(after(key))
                )
            }
    }

    /// One row per screen or area whose own edge changed (#1948,
    /// #3517), under its bar's edge label and the screen's whole
    /// fingerprint — two models of one name differ by size — each
    /// side the edge that screen or area actually gets.
    static func screenEdgeRows<Bar: ScreenEdged>(
        _ census: SettingKey,
        bar: KiwiShelfKey,
        _ old: Bar,
        _ new: Bar,
        splits: [String: ScreenSplit]
    ) -> [SettingsDiffRow] {
        let base = label(for: .kiwishelf(bar))
        let name: (AppBarEdge) -> String = { edge in
            AppBarOptions.edge.first { $0.0 == edge }?.1 ?? ""
        }
        let screens = Set(old.edgeOverride.keys)
            .union(new.edgeOverride.keys)
        return
            screens
            .filter { old.edge(on: $0) != new.edge(on: $0) }
            .sorted()
            .map { screen in
                let parts = Display.fingerprintParts(
                    ScreenAreaKey(parsing: screen).fingerprint
                )
                return .change(
                    census,
                    instance: screen,
                    label: instanceLabel(
                        base,
                        SettingsModel.perScreenName(
                            screen: "\(parts.name) \(parts.size)",
                            key: screen,
                            splits: splits
                        )
                    ),
                    old: name(old.edge(on: screen)),
                    new: name(new.edge(on: screen))
                )
            }
    }
}
