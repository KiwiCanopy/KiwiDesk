import KiwiDeskCore

/// Stored leaves a master row writes (#754).
/// `SettingsDraftDiff` books a leaf to the census row owning the longest
/// model-path prefix, so masters with followers under them need no entry;
/// masters writing across the model declare writes here so one edit books
/// as one change (`SettingsDraftDiffTests`, `LiquidGlassMasterTests`).
extension SettingKey {
    static let masterWrites: [SettingKey: [String]] = [
        .kiwishelf(.edge): [
            "settings.spaceBarStyle.edge",
            "settings.appBarStyle.edge",
        ],
        // Every bar's own visibility (#761): the Space Bar's and each
        // layout that hosts an App Bar, read off Core's hosting set.
        .kiwishelf(.visibility): ["settings.spaceBarStyle.visibility"]
            + LayoutMode.allCases
            .filter { TilingSettings().appBarHost(for: $0) != nil }
            .map { "settings.\($0.rawValue).appBar.visibility" },
        .colours(.liquidGlassMaster): [
            "settings.kiwishelf.liquidGlass",
            "settings.shortcutPanelLiquidGlass",
            "settings.dragLiquidGlass",
            "settings.stickyStyle.liquidGlass",
        ],
    ]
}
