import KiwiDeskCore
import SwiftUI

/// Phase 1 of the reveal pipeline (#277), split from
/// `SettingsView` at the 350-line ceiling: the shell's
/// application of a navigation request. Phase 2 (the
/// scroll driver) stays in `SettingsView.reveal`, which
/// owns the `@State` task it supersedes.
extension SettingsView {
    /// Phase 1 of a reveal: destination and surface, the half
    /// that is meaningful in both modes. The **only** consumer of
    /// `pendingReveal`, and it clears it.
    ///
    /// Phase 2 goes to `pendingScroll`, so each field has one
    /// writer and one clearer. An earlier cut had both this and
    /// the pane's scroll driver observing `pendingReveal`, with
    /// the driver clearing it — and since the outer `.onAppear`
    /// re-read the model rather than a captured value, a
    /// child-first `onAppear` order (SwiftUI does not specify it)
    /// let the driver blank the request before this ran. The #326
    /// "Edit in Settings…" bridge would then land on Profiles,
    /// which `SettingsWindowController.show()` had just set.
    ///
    /// Handing phase 2 to its own field also keeps the property
    /// that motivated the split: a request arriving while the raw
    /// Lua editor shows still resolves later, because
    /// `pendingScroll` simply waits for a pane to exist.
    /// The decision lives on `SettingsAnchor.resolved`, which is
    /// pure and tested; this is only the assignment.
    ///
    /// LOAD-BEARING PLACEMENT: the `.onChange`/`.onAppear` pair
    /// that calls this sits on the outer `Group`, ABOVE the
    /// `editingLua` branch. That is the sole reason a request
    /// arriving while the raw Lua editor shows resolves later
    /// instead of being dropped. Moving it into `structuredShell`
    /// would look like a tidy-up and would silently kill the #326
    /// bridge in Lua mode, with every test still green.
    func apply(_ request: SettingsAnchor?) {
        guard let request else { return }
        model.nav.pendingReveal = nil
        guard
            let resolved = request.resolved(
                editingStoredProfile: model.editingStoredProfile
            )
        else { return }
        model.destination = resolved.destination
        switch resolved.surface {
        case .main:
            break
        case .layoutMode(let mode):
            model.nav.layoutModeTab = mode
        }
        // Unconditional, including the nil case. Guarding it to
        // avoid a nil→nil publish would mean a destination-only
        // request stops CLEARING a `pendingScroll` an earlier
        // reveal left unconsumed — the driver would then scroll
        // and wash the old anchor inside the new destination.
        // That trades a guaranteed supersede for one saved
        // re-render, in the field whose whole design is one
        // writer and one clearer.
        model.nav.pendingScroll = resolved.scroll
        // The standing copy drawers read to auto-expand (#277).
        // Written here only; cleared by `endFlash`.
        model.nav.setRevealTarget(resolved.scroll)
    }
}
