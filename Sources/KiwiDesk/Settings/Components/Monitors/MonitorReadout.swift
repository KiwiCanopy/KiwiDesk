import KiwiDeskCore

/// What one display currently holds, in a sentence (#678 Phase 3,
/// turn 13b): "2 spaces here · code is showing".
///
/// Authored once and read twice — the line under the picture
/// says it, and the selected card speaks it to VoiceOver and
/// shows it on hover. Two copies of one sentence is how a
/// tooltip and a caption come to describe the same display
/// differently.
///
/// **"is showing" is per display and stays that way.** It comes
/// from `WorkspaceManager.activeSpace(on:)`, which is the single
/// truth the tiler lays out per display and the bars read — a
/// KiwiDesk space, not a macOS Desktop. It is therefore
/// independent of macOS's "Displays have separate Spaces", which
/// gates the Desktop→profile bindings in Profiles and nothing
/// here.
@MainActor
enum MonitorReadout {
    static func sentence(
        held: Int,
        showing: SpaceID?
    ) -> String {
        // A localized PHRASE per count, never "%1$d space(s)":
        // an English plural glued to a number reads "1 spaces" in
        // the language it was written for and cannot be declined
        // in the ten it was not.
        let phrase =
            held == 1
            ? L("monitors.selection.one", "1 space here")
            : L(
                "monitors.selection.many",
                "%1$d spaces here",
                held
            )
        guard let showing else { return phrase }
        return L(
            "monitors.selection.showing",
            "%1$@ · %2$@ is showing",
            phrase,
            showing.raw
        )
    }
}
