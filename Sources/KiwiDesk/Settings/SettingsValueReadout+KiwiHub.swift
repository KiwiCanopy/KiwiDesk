import KiwiDeskCore

/// KiwiHub's navigation key alternatives in the diff (#2600).
extension SettingsValueReadout {
    static func kiwiHubKeyRows(
        _ key: BehaviourKey,
        _ census: SettingKey,
        _ before: TilingSettings,
        _ after: TilingSettings
    ) -> [SettingsDiffRow] {
        guard let hubKey = key.kiwiHubKey else { return [] }
        return [
            .change(
                census,
                label: L(
                    "diff.label.kiwihub_key",
                    "KiwiHub key for %1$@",
                    glyph(of: hubKey)
                ),
                old: shortcutsCombo(before.kiwihub.key[hubKey] ?? ""),
                new: shortcutsCombo(after.kiwihub.key[hubKey] ?? "")
            )
        ]
    }

    /// The built-in key's own glyph, as KiwiHub's footer draws it.
    static func glyph(of key: KiwiHubKey) -> String {
        switch key {
        case .up: return "↑"
        case .down: return "↓"
        case .pageUp: return "⇞"
        case .pageDown: return "⇟"
        case .left: return "←"
        case .right: return "→"
        }
    }
}
