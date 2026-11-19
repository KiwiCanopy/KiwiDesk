import KiwiDeskCore

/// How a Desktop label names a screen (#2792), shared by KiwiHub,
/// the Desktop switch plate, the Shortcuts landing lines and the
/// minimum-size fit line.
extension ScreenLabel {
    /// Its own name, or its position where another connected
    /// screen shares it — "Twin (left)", as the Screens page and
    /// KiwiHub's Desktop headings say (#3502).
    @MainActor var displayName: String {
        ScreenShiftText.named(name, at: twinPosition)
    }
}
