import KiwiDeskCore

/// Transient navigation and search reveal state for settings window (#277).
struct SettingsNavigation {
    /// Pending navigation target from search or shortcuts bridge
    /// (#326, #277). A request arriving while the raw Lua editor
    /// shows lingers and resolves when the visual editor returns —
    /// the detail pane is where a scroll target can exist.
    var pendingReveal: SettingsAnchor?
    /// Notification target for mode switch during search reveal
    /// (#678 4c) — consumed by the SAME apply that flips the mode,
    /// so a refused or superseded reveal announces nothing.
    var pendingModeNotice: SettingsDestination?
    /// Active highlight flash state (#277).
    private(set) var flash: SettingsFlash?
    private var flashToken = 0
    /// Target anchor ID for scrolling phase of reveal.
    var pendingScroll: String?
    /// Standing target ID from `apply` until the flash ends. One
    /// writer (`SettingsView.apply`), one clearer (`endFlash`) —
    /// the part-1 #326 bug was two observers of one field clearing
    /// in unspecified `onAppear` order.
    private(set) var revealTarget: String?

    mutating func setRevealTarget(_ id: String?) {
        revealTarget = id
    }

    /// Active layout mode tab selection in Layout Defaults — on
    /// the model, not view `@State` (#277): outside code must be
    /// able to set and clear it.
    var layoutModeTab: LayoutMode?

    /// Active space ID for pushed space overrides editor (#678).
    var spaceOverridesFocus: SpaceID?

    /// Originating card destination when popping back to Home.
    var homeReturnFocus: SettingsDestination?

    /// Resets transient surface selections to default — for window
    /// open and an edit-target switch: moving these off view-local
    /// `@State` (#277) silently promoted a per-visit landing to a
    /// process-lifetime one.
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

    /// Concludes flash animation if token is still current. Must
    /// be called: `.task(id:)` re-runs on appear, so a value left
    /// standing re-washes the card on every navigation back; the
    /// token keeps a superseded finisher from cancelling.
    mutating func endFlash(token: Int) {
        guard flash?.token == token else { return }
        flash = nil
        revealTarget = nil
    }
}
