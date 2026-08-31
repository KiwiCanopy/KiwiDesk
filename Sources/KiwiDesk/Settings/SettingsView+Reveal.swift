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
        // Taken unconditionally, so a REFUSED request cannot
        // leave a stale arm for the next reveal to announce.
        let armedNotice = model.nav.pendingModeNotice
        model.nav.pendingModeNotice = nil
        guard
            let resolved = request.resolved(
                editingStoredProfile: model.editingStoredProfile
            )
        else { return }
        let wasSimple = model.settingsMode == .simple
        ensureModeAdmits(resolved.destination)
        if let armedNotice, wasSimple,
            model.settingsMode == .powerUser
        {
            model.noteSearchModeSwitch(armedNotice)
        }
        model.destination = resolved.destination
        switch resolved.surface {
        case .main:
            break
        case .layoutMode(let mode):
            model.nav.layoutModeTab = mode
        }
        // Unconditional, nil included: guarding a nil→nil publish
        // would stop a destination-only request from CLEARING an
        // unconsumed `pendingScroll`, and the driver would wash
        // the old anchor inside the new destination.
        model.nav.pendingScroll = resolved.scroll
        model.nav.setRevealTarget(resolved.scroll)
    }
}
