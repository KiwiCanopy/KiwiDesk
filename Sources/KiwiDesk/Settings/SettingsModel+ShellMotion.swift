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
        guard old != new else { return }
        defer { nav.pendingShellMotion = nil }
        if let named = nav.pendingShellMotion {
            nav.shellMotion = named
        } else if let old, new == nil, nav.homeReturnFocus == old {
            nav.shellMotion = .expand(old)
        } else {
            nav.shellMotion = .zoomThrough
        }
    }

    /// The cause of a root change: the switch converges. Called after
    /// the destination, which records its own when a page changed.
    func recordShellMotion(from old: SettingsRoot) {
        guard settingsRoot != old, destination == nil else { return }
        nav.shellMotion = .converge
        nav.convergePending = true
    }
}
