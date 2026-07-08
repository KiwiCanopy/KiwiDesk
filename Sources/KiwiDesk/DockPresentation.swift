import AppKit

extension NSApplication {
    /// Raise KiwiDesk to `.regular` (Dock tile + menu bar) and
    /// assert its Dock icon.
    ///
    /// The bare executable ships no `.icns`, so the tile created
    /// on promotion shows the generic placeholder. An
    /// `applicationIconImage` set earlier — while `.accessory`,
    /// before any tile exists — does not carry onto that fresh
    /// tile, so the mark must be applied *after* the policy
    /// flip. The packaged `.app` (#89) will supply a real icon
    /// and make the image assignment a harmless no-op.
    @MainActor func activateAsRegular() {
        setActivationPolicy(.regular)
        if let icon = BrandAssets.appMark {
            applicationIconImage = icon
        }
    }
}
