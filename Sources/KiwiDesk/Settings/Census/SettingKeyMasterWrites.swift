/// Stored leaves a master row writes (#754).
/// Declares multi-leaf writes for unsaved-change attribution in
/// `SettingsDraftDiff` (`SettingsDraftDiffTests`, `BorderMastersFanOutTests`).
extension SettingKey {
    static let masterWrites: [SettingKey: [String]] = [
        .borders(.borderWidthMaster): [
            "settings.borderStyle.width",
            "settings.dragGhost.borderWidth",
            "settings.dragDropZone.borderWidth",
        ],
        .borders(.borderCornerMaster): [
            "settings.borderStyle.cornerStyle",
            "settings.dragCornerRadius",
        ],
    ]
}
