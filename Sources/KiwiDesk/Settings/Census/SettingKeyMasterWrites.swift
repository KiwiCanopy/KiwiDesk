/// Stored leaves a master row writes (#754).
/// `SettingsDraftDiff` books a leaf to the census row owning the longest
/// model-path prefix, so masters with followers under them need no entry;
/// masters writing across the model declare writes here so one edit books
/// as one change (`SettingsDraftDiffTests`, `BorderMastersFanOutTests`).
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
