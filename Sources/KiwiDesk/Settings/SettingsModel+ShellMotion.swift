import KiwiDeskCore

/// The one owner of `nav.shellMotion` (#2737 ruling 13): a change of
/// the shown root records its cause in its `didSet`, so no door can
/// forget one. A page change records nothing; it swaps at once.
extension SettingsModel {
    /// A Home card opening its page, remembered so Back returns focus
    /// to the card.
    func openFromCard(_ destination: SettingsDestination) {
        nav.homeReturnFocus = destination
        self.destination = destination
    }

    /// The cause of a root change: the switch converges. Called after
    /// the destination, so a link's landing on a page stays unmoved.
    func recordShellMotion(from old: SettingsRoot) {
        guard settingsRoot != old, destination == nil else { return }
        nav.shellMotion = .converge
        // Only Home arriving owes the cards' flight.
        nav.convergePending = settingsRoot == .advanced
    }
}
