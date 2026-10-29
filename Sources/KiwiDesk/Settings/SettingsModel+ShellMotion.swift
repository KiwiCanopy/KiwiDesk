import KiwiDeskCore

/// The one owner of `nav.shellMotion` (#2737 ruling 13): every
/// change of the shown root or destination records its cause in
/// their `didSet`s, so no door can forget one, and a door that
/// means another motion names it here.
extension SettingsModel {
    /// A Home card opening its page: the page grows out of it, and
    /// Back folds it into the card again.
    func openFromCard(_ destination: SettingsDestination) {
        nav.homeReturnFocus = destination
        nav.pendingShellMotion = .expand(destination)
        nav.contentLagPending = true
        self.destination = destination
    }

    /// The cause of a destination change: a door's named motion,
    /// else Back to the card a page grew out of, else a landing
    /// with no card behind it.
    /// Called after the root, so a link's landing zooms through.
    func recordShellMotion(
        from old: SettingsDestination?,
        to new: SettingsDestination?
    ) {
        // Consumed whatever the write, so a named motion never
        // outlives the change it was named for.
        defer { nav.pendingShellMotion = nil }
        guard old != new else { return }
        if let named = nav.pendingShellMotion {
            nav.shellMotion = named
        } else if let old, new == nil, nav.homeReturnFocus == old {
            nav.shellMotion = .expand(old)
        } else {
            nav.shellMotion = .zoomThrough
            // A landing breaks the line back to the card, so a later
            // Back does not fold into a card it never left.
            nav.homeReturnFocus = nil
            nav.contentLagPending = false
        }
    }

    /// The cause of a root change: the switch converges. Called after
    /// the destination, which records its own when a page changed.
    func recordShellMotion(from old: SettingsRoot) {
        guard settingsRoot != old, destination == nil else { return }
        nav.shellMotion = .converge
        // Only Home arriving owes the cards' flight.
        nav.convergePending = settingsRoot == .advanced
    }
}
