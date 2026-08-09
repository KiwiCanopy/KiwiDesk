/// Which stored leaves a MASTER row writes (#754) — one
/// control over several values, declared as data so the
/// unsaved-changes count can book one edit as one change.
///
/// `SettingsDraftDiff` attributes a changed leaf to the census
/// row whose model path owns the longest prefix of it, which is
/// enough while a master's followers sit UNDER it: the gaps
/// outer master's id prefixes the four edges it writes. The
/// border masters write across the model — the ring's own leaf
/// and the drag pair's — so no prefix reaches them, and one
/// nudge of the shared Width slider read as three unsaved
/// changes until this map existed.
///
/// **A master row that writes a leaf with no GUI surface of its
/// own declares that leaf here.** A leaf that HAS its own row
/// stays out: the per-edge gap sliders are settings a user
/// edits one at a time, and editing two of them is honestly two
/// changes (`SettingsDraftDiffTests.siblingsStayDistinct`) — so
/// the gap masters' own fan-out is deliberately absent from
/// this map and their count is still per edge.
///
/// The lists are a second copy of what the bindings in
/// `SettingsModel+Borders` actually write.
/// `BorderMastersFanOutTests` closes that by writing each
/// master and comparing the leaves that moved against the
/// declaration, so a master growing a fourth stroke cannot
/// leave this behind.
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
