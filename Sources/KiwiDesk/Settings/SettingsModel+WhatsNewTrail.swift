import KiwiDeskCore

/// The trail back to What's new (#2038 ruling ▸ handoff): one
/// writer of `whatsNewTrail` per trigger, and every landing
/// through the search's own reveal — so nothing here writes the
/// draft or the profile.
extension SettingsModel {
    /// Lands on the trail's row, as a search pick would, mode
    /// switch included, and keeps the way back.
    func follow(_ trail: WhatsNewTrail) {
        whatsNewTrail = trail
        land(on: trail.current)
    }

    /// Next: the following linked row, in place.
    func followNext() {
        guard let next = whatsNewTrail?.advanced() else { return }
        whatsNewTrail = next
        land(on: next.current)
    }

    /// Back to What's new: the banner goes, What's new returns.
    func returnToWhatsNew() {
        guard let trail = takeTrail() else { return }
        trail.back()
    }

    /// ×: the banner goes and What's new is finished.
    func dismissWhatsNew() {
        guard let trail = takeTrail() else { return }
        trail.dismiss()
    }

    /// Settings closing while What's new is hidden re-presents it
    /// (owner ruling): the banner goes with the window.
    func settingsClosed() {
        returnToWhatsNew()
    }

    private func takeTrail() -> WhatsNewTrail? {
        defer { whatsNewTrail = nil }
        return whatsNewTrail
    }

    private func land(on stop: WhatsNewTrail.Stop) {
        // Armed every time: `apply` announces only a flip it made.
        nav.pendingModeNotice = stop.anchor.destination
        nav.pendingReveal = stop.anchor
    }
}
