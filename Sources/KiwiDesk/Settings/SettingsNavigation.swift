import KiwiDeskCore

/// Transient navigation and search reveal state for settings window (#277).
struct SettingsNavigation {
    /// Pending navigation target from search or shortcuts bridge
    /// (#326, #277). A request arriving while the raw Lua editor
    /// shows lingers and resolves when the visual editor returns —
    /// the detail pane is where a scroll target can exist.
    var pendingReveal: SettingsAnchor?
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

    /// Selected keybinding layer in Shortcuts — on the model
    /// rather than the section's `@State` (#1127), because the
    /// live preview panel is the section's SIBLING: the
    /// `keybindingLayerName` environment the rows read never
    /// reaches it. Read it through `shortcutsLayerSelection`.
    var shortcutsLayer: String?

    /// The selected layer, coalesced ONCE: nothing latches the
    /// field, so a reader spelling the landing itself is how the
    /// `layoutModeTab` pair came to answer `.bsp` in the panel
    /// and `LayoutUsage.mostUsed` in the section (#1127).
    var shortcutsLayerSelection: String {
        shortcutsLayer ?? KeyLayer.defaultName
    }

    /// The lens chip selected on KiwiVision, nil for Default —
    /// on the model for the same reason as
    /// `shortcutsLayer`: the side panel follows it (#2103 ruling
    /// 29). Read it through `kiwiVisionLensSelection(in:)`.
    var kiwiVisionLens: String?

    /// A landing asked for the add-lens popover (#2359 ruling 4);
    /// the lens strip opens it once and clears this.
    var kiwiVisionAddRequested = false

    /// The selected lens's page spelling among `lenses`, nil for
    /// Default or a lens no longer listed.
    func kiwiVisionLensSelection(in lenses: [VisionLens]) -> String? {
        kiwiVisionLens.flatMap { name in
            lenses.first { AppWideSettings.sameLens($0.name, name) }?.name
        }
    }

    /// Active space ID for pushed space overrides editor (#678).
    var spaceOverridesFocus: SpaceID?

    /// The look the pointer previews on Simple's Space cards, nil
    /// at rest (#2777).
    var simpleHover: SimplePreviewHover?

    /// Why the shell last changed, so it plays that motion. Written
    /// only by `SettingsModel`'s root and destination `didSet`s.
    var shellMotion: ShellMotion = .none

    /// A motion a door names for the change it is about to make,
    /// consumed by that change (`openFromCard`).
    var pendingShellMotion: ShellMotion?

    /// Whether Home's cards still owe the switch's converge; Home
    /// plays it once and clears this, so a remount does not replay it.
    var convergePending = false

    /// Whether the page a card just opened still owes its content's
    /// late fade; the page plays it once, so a remount shows at once.
    var contentLagPending = false

    /// Originating card destination when popping back to Home.
    var homeReturnFocus: SettingsDestination?

    /// Whether the navigation that last moved `destination` — or
    /// changed the What's new trail's shape in place (#2038) —
    /// would have moved focus on the platform's own (#991).
    /// Written from `SettingsInputSource` at two moments only —
    /// `SettingsModel.destination`'s `didSet`, and the trail's
    /// in-place navigations, which move no destination
    /// (`SettingsModel+WhatsNewTrail`) — and meaningful only to a
    /// statement fired BY that write, so a reader at an unpaired
    /// moment would get the verdict for whatever navigated last.
    var navigationMovesFocus = false

    /// Bumped by the trail's Next and × (#2038): the shell, which
    /// outlives the banner, states the focus destination (#996).
    var trailFocusRequest = 0

    /// Resets transient surface selections to default — for window
    /// open and an edit-target switch: moving these off view-local
    /// `@State` (#277) silently promoted a per-visit landing to a
    /// process-lifetime one.
    mutating func resetSurfaces() {
        layoutModeTab = nil
        shortcutsLayer = nil
        kiwiVisionLens = nil
        kiwiVisionAddRequested = false
        spaceOverridesFocus = nil
        simpleHover = nil
        shellMotion = .none
        pendingShellMotion = nil
        convergePending = false
        contentLagPending = false
        // The latch is paired with the write that set it, so it
        // must not outlive the visit — a window re-shown states
        // no destination rather than one the last visit earned.
        navigationMovesFocus = false
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
