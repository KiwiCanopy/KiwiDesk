import KiwiDeskCore
import SwiftUI

/// Phase 1 of settings reveal navigation pipeline (#277, #326).
extension SettingsView {
    /// Applies destination and surface navigation from pending reveal request
    /// (`SettingsAnchor.resolved`, #277, #326, #678).
    func apply(_ request: SettingsAnchor?) {
        guard let request else { return }
        model.nav.pendingReveal = nil
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
        model.nav.pendingScroll = resolved.scroll
        model.nav.setRevealTarget(resolved.scroll)
    }
}
