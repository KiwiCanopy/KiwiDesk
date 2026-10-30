import KiwiDeskCore

/// How a Desktop label names a screen (#2792), shared by KiwiHub
/// and the Desktop switch plate.
extension ScreenLabel {
    /// Its own name, or "Main screen" / "Screen 2" where another
    /// connected screen shares it.
    @MainActor var displayName: String {
        twinPlace.map(presetScreenName) ?? name
    }
}
