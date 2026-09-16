import KiwiDeskCore

/// Localized screen count phrase, shared by the Profiles cards
/// — the Saved profiles subtitle, the Which-loads sentence and
/// the Desktops card's count groups (#1436).
@MainActor
func screensPhrase(_ count: Int) -> String {
    count == 1
        ? L("profiles.screens.one", "1 screen")
        : L("profiles.screens.many", "%1$d screens", count)
}
