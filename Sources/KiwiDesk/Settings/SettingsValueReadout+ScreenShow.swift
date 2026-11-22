import KiwiDeskCore

/// A bar's per-screen and per-area Show in the diff (#3517 ruling
/// 30), split from `SettingsValueReadout+KiwiShelf.swift`.
extension SettingsValueReadout {
    /// One row per screen or area whose Show changed, labelled with
    /// the bar's per-screen label and the key's screen, each side
    /// the value that screen shows: its own, else `own` — the Space
    /// Bar's own value — or Per layout for the App Bar.
    static func screenShowRows(
        _ census: SettingKey,
        _ old: [String: ShelfVisibility],
        _ new: [String: ShelfVisibility],
        own: (old: ShelfVisibility, new: ShelfVisibility)?
    ) -> [SettingsDiffRow] {
        let base =
            census == .kiwishelf(.appBarScreenVisibility)
            ? appBarScreenShowLabel : spaceBarScreenShowLabel
        let name: (ShelfVisibility?) -> String = { value in
            guard let value else { return SettingsModel.perLayout }
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
                    areaID: area.areaID,
                    split: area.areaID != 0
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

    /// The census labels of the two rows, spelled where the scanner
    /// reads them.
    static var spaceBarScreenShowLabel: String {
        L("kiwishelf.show.per_screen.space_bar", "Space Bar: Show per screen")
    }

    static var appBarScreenShowLabel: String {
        L("kiwishelf.show.per_screen.app_bar", "App Bar: Show per screen")
    }
}
