import KiwiDeskCore

/// The Simple | Advanced switch's converge debt (#2737 ruling 13),
/// recorded in `settingsRoot`'s `didSet`. A page change records
/// nothing: it swaps at once.
extension SettingsModel {
    /// A Home card opening its page, remembered so Back returns focus
    /// to the card.
    func openFromCard(_ destination: SettingsDestination) {
        nav.homeReturnFocus = destination
        self.destination = destination
    }

    /// Owes the root the switch lands on its cards' flight: Home's
    /// grid, or Simple's sections (#2777). Called after the
    /// destination, so a link from Simple landing on a page owes none.
    func recordConverge(from old: SettingsRoot) {
        guard settingsRoot != old, destination == nil else { return }
        nav.convergePending = true
    }
}
