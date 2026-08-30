import KiwiDeskCore

/// Transient navigation and search reveal state for settings window (#277).
struct SettingsNavigation {
    /// Pending navigation target from search or shortcuts bridge (#326, #277).
    var pendingReveal: SettingsAnchor?
    /// Notification target for mode switch during search reveal (#678).
    var pendingModeNotice: SettingsDestination?
    /// Active highlight flash state (#277).
    private(set) var flash: SettingsFlash?
    private var flashToken = 0
    /// Target anchor ID for scrolling phase of reveal.
    var pendingScroll: String?
    /// Standing target ID during reveal animation.
    private(set) var revealTarget: String?

    mutating func setRevealTarget(_ id: String?) {
        revealTarget = id
    }

    /// Active layout mode tab selection in Layout Defaults (#277).
    var layoutModeTab: LayoutMode?

    /// Active space ID for pushed space overrides editor (#678).
    var spaceOverridesFocus: SpaceID?

    /// Originating card destination when popping back to Home.
    var homeReturnFocus: SettingsDestination?

    /// Resets transient surface selections to default.
    mutating func resetSurfaces() {
        layoutModeTab = nil
        spaceOverridesFocus = nil
    }

    /// Triggers flash highlight for anchor, returning new token (#277).
    mutating func startFlash(_ anchor: String) -> Int {
        flashToken += 1
        flash = SettingsFlash(
            anchor: anchor,
            token: flashToken
        )
        return flashToken
    }

    /// Concludes flash animation if token is still current.
    mutating func endFlash(token: Int) {
        guard flash?.token == token else { return }
        flash = nil
        revealTarget = nil
    }
}
