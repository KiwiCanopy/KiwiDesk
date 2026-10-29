import KiwiDeskCore
import SwiftUI

/// Phase 1 of settings reveal navigation pipeline (#277, #326).
extension SettingsView {
    /// Applies destination and surface from a pending reveal —
    /// the ONLY consumer of `pendingReveal`, and it clears it;
    /// phase 2 goes to `pendingScroll`, one writer one clearer
    /// (`SettingsAnchor.resolved`, #277, #678). LOAD-BEARING
    /// PLACEMENT: the `.onChange`/`.onAppear` pair calling this
    /// sits on the outer `Group`, ABOVE the `editingLua` branch —
    /// the sole reason a request arriving in Lua mode resolves
    /// later. Moving it into `structuredShell` looks like a
    /// tidy-up and silently kills the #326 bridge, every test
    /// green.
    func apply(_ request: SettingsAnchor?) {
        guard let request else { return }
        model.nav.pendingReveal = nil
        guard
            let resolved = request.resolved(
                editingStoredProfile: model.editingStoredProfile
            )
        else { return }
        // No card stands behind a landing, so it zooms through.
        model.nav.shellMotion = .zoomThrough
        model.destination = resolved.destination
        // Every KiwiVision anchor but the strip's lives on the
        // Default page, and a landing names no lens (#2103).
        if resolved.destination == .kiwiVision {
            model.nav.kiwiVisionLens = nil
        }
        var scroll = resolved.scroll
        switch resolved.surface {
        case .main:
            break
        case .layoutMode(let mode):
            model.nav.layoutModeTab = mode
        case .space(let space):
            model.nav.spaceOverridesFocus = space
        case .appRule(let app):
            // Scroll and flash, as the search lands — no focus: a
            // navigation moves focus only where macOS would (#991).
            scroll = AppRulesSection.card(holding: app, in: model)?.id
        case .newLens:
            model.nav.kiwiVisionAddRequested = true
        }
        // Unconditional, nil included: guarding a nil→nil publish
        // would stop a destination-only request from CLEARING an
        // unconsumed `pendingScroll`, and the driver would wash
        // the old anchor inside the new destination.
        model.nav.pendingScroll = scroll
        model.nav.setRevealTarget(scroll)
    }
}
