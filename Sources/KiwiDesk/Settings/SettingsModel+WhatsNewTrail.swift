import KiwiDeskCore

/// External landings and the trail back to What's new (#2038
/// ruling ▸ handoff). Every landing goes through the search's own
/// reveal, so nothing here writes the draft or the profile.
extension SettingsModel {
    /// The one door an outside surface lands Settings through — a
    /// bar menu's row (#1518) or a spotlight row (#2038) — arming
    /// the mode notice only where the landing flips the mode, as a
    /// search pick does (`SettingsSearch.switchesMode`).
    func land(on anchor: SettingsAnchor) {
        if !HomeCardOrder.isOffered(
            anchor.destination,
            mode: settingsMode,
            displayCount: displays.count,
            editingStoredProfile: editingStoredProfile
        ) {
            nav.pendingModeNotice = anchor.destination
        }
        nav.pendingReveal = anchor
    }

    /// Lands on the trail's row and keeps the way back.
    func follow(_ trail: WhatsNewTrail) {
        whatsNewTrail = trail
        land(on: trail.current.anchor)
    }

    /// Next: the following linked row, in place; focus follows it
    /// where the platform would have moved focus (#991).
    func followNext() {
        guard let next = whatsNewTrail?.advanced() else { return }
        whatsNewTrail = next
        land(on: next.current.anchor)
        stateTrailFocus()
    }

    /// Back to What's new: the banner goes, What's new returns
    /// and takes the focus with its window.
    func returnToWhatsNew() {
        guard let trail = takeTrail() else { return }
        trail.back()
    }

    /// ×: the banner goes, What's new is finished, and focus stays
    /// on the landed control's pane (#991).
    func dismissWhatsNew() {
        guard let trail = takeTrail() else { return }
        trail.dismiss()
        stateTrailFocus()
    }

    /// Settings closing while What's new is hidden: the banner
    /// goes with the window, and the coordinator decides whether
    /// What's new comes back (owner ruling).
    func settingsClosed() {
        guard let trail = takeTrail() else { return }
        trail.settingsClosed()
    }

    private func takeTrail() -> WhatsNewTrail? {
        defer { whatsNewTrail = nil }
        return whatsNewTrail
    }

    /// The banner changed shape under the pointer or the keyboard:
    /// record the input source and ask the shell for a statement.
    private func stateTrailFocus() {
        nav.navigationMovesFocus = SettingsInputSource.movesFocus
        nav.trailFocusRequest += 1
    }
}
