import KiwiDeskCore

/// The Settings window's transient navigation state, collapsed
/// behind one `@Published var nav` on `SettingsModel` (#277).
///
/// A value type on purpose: `$model.nav.layoutModeTab` still
/// projects a `Binding`, so call sites keep their shape while the model
/// file stays under the 350-line ceiling as part 2 grows this set
/// (drawer expansions, the Shortcuts mode strip). Everything here
/// is a one-shot navigation request or a local surface selection —
/// never edited config, which stays on the model.
///
/// `pendingScroll`, `revealTarget` and `flash` are three facets of
/// one in-flight reveal, held apart because their lifetimes differ
/// (consumed-immediately vs stands-until-flash-ends). A *fourth*
/// facet would be the point to fold them into a single reveal
/// state-machine value rather than more correlated optionals —
/// worth weighing when the Shortcuts mode strip lands.
struct SettingsNavigation {
    /// A one-shot navigation request: a sidebar destination, the
    /// local surface to switch to, and optionally a label to
    /// scroll to and flash. Serves both the read-only shortcuts
    /// panel's "Edit in Settings…" bridge (#326, destination
    /// only) and a sidebar search hit (#277, full anchor).
    ///
    /// `SettingsView` applies the destination and surface; the
    /// detail pane's scroll driver performs the reveal and clears
    /// this. A request that arrives while the raw Lua editor is
    /// showing therefore lingers rather than being dropped, and
    /// resolves when the visual editor comes back — the detail
    /// pane is where a scroll target can exist at all.
    var pendingReveal: SettingsAnchor?
    /// The flash in progress. Read into the environment so each
    /// anchored view can recognize itself; nil between reveals.
    /// Written only through `startFlash` / `endFlash`, which own
    /// the re-trigger token.
    private(set) var flash: SettingsFlash?
    private var flashToken = 0
    /// Phase 2 of a reveal: the anchor id whose pane is now
    /// showing and can be scrolled. Minted by
    /// `SettingsView.apply` once the destination and surface are
    /// set, consumed by the detail pane's scroll driver — see
    /// `pendingReveal` for why the two phases are separate
    /// fields.
    var pendingScroll: String?
    /// The reveal's target id, standing from `apply` until the
    /// flash ends — unlike `pendingScroll`, which the scroll
    /// driver consumes immediately. Read (never written) by
    /// `SettingsDisclosure` through the environment, so a drawer
    /// holding the target can expand before the driver's
    /// re-issued `scrollTo`. One writer (`SettingsView.apply`),
    /// one clearer (`endFlash`) — the part-1 #326 bug was two
    /// observers of one field, one of which cleared it in
    /// unspecified `onAppear` order.
    private(set) var revealTarget: String?

    /// `apply`'s write, unconditional for the same supersede
    /// reason as `pendingScroll`: a destination-only request
    /// must clear a stale target too.
    mutating func setRevealTarget(_ id: String?) {
        revealTarget = id
    }
    /// The Layout Defaults mode tab (the Bars editor switch it
    /// sat beside died with the one-page Bars area, #678
    /// Phase 2).
    ///
    /// On the model rather than in the owning view's `@State`
    /// (#277): a search hit on a mode-gated control has to
    /// select the surface that renders it before there is
    /// anything to scroll to, and view-local state cannot be set
    /// from outside. Starts nil so the section can still land on
    /// the profile's most-used mode the first time it appears; a
    /// user's later pick, and a reveal, both write it.
    var layoutModeTab: LayoutMode?

    /// The space whose per-space override editor is pushed over
    /// the Spaces list, or nil for the list itself (#678 8b). On
    /// the model, not the section's `@State`, for the same #277
    /// reason `layoutModeTab` is: a selection that outside code
    /// (a reset, an edit-target switch) must be able to clear.
    /// The editor is a view-state branch, not a `SettingsSurface`
    /// — the override controls are per-space and uncataloged, so
    /// there is nothing for search or the #326 bridge to reveal;
    /// add a `.spaceOverrides(SpaceID)` surface only if a
    /// deep-link INTO a specific space's editor is later wanted.
    var spaceOverridesFocus: SpaceID?

    /// Forgets the surface selection, so it re-derives its
    /// default. For window open, which re-asserts `destination`
    /// for the same reason, and for an **edit-target switch**,
    /// where a different profile means a different most-used
    /// mode. Moving this off view-local `@State` (#277) silently
    /// promoted a per-visit landing to a process-lifetime one.
    ///
    /// Also drops the pushed override editor back to the list, so
    /// opening the window (or switching edit target) never lands
    /// on a stale per-space editor.
    mutating func resetSurfaces() {
        layoutModeTab = nil
        spaceOverridesFocus = nil
    }

    /// Starts a flash on `anchor`, bumping the token so that
    /// revealing the same anchor twice still re-fires (#277).
    mutating func startFlash(_ anchor: String) -> Int {
        flashToken += 1
        flash = SettingsFlash(
            anchor: anchor,
            token: flashToken
        )
        return flashToken
    }

    /// Ends the flash, if `token` is still the current one.
    ///
    /// Must be called: `SearchRevealFlash` uses `.task(id:)`,
    /// which runs on *appear* as well as on change, so a value
    /// left standing re-washes the card every time the user
    /// navigates back to it — no user action involved. The token
    /// check makes a late finisher from a superseded flash unable
    /// to cancel the current one.
    ///
    /// Also retires `revealTarget` (same token guard): clearing
    /// it is what lets a later reveal of the same id register as
    /// a change on a drawer the user has re-collapsed meanwhile.
    mutating func endFlash(token: Int) {
        guard flash?.token == token else { return }
        flash = nil
        revealTarget = nil
    }
}
