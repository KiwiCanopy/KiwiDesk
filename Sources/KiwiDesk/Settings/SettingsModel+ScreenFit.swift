import KiwiDeskCore

/// The fit rule on the Screens cards (#3647 ▸ no-fit ruling): which
/// numbers a screen's badge greys, and why a screen draws whole.
/// Every answer is Core's verdict and fit search over the draft.
extension SettingsModel {
    /// The axis along which `display`'s number's split falls under
    /// the draft's floor there, so it draws whole; nil where it
    /// draws as stored.
    func unsplitAxis(of display: Display) -> ScreenAreaCut.Axis? {
        let verdict = config.settings.displayAreas.verdict(
            on: display.fingerprint,
            order: screenOrder,
            floors: config.settings.areaFloors
        )
        if case .tooSmall(let axis) = verdict { return axis }
        return nil
    }

    /// Whether some order of the connected screens fits every split:
    /// read once per menu, since it names no item.
    var anyScreenOrderFits: Bool {
        screenOrder.anyFits(
            config.settings.displayAreas,
            floors: config.settings.areaFloors
        )
    }

    /// Whether `display` may take Screen `number`: false only where
    /// some order fits every screen (`anyFits`, `anyScreenOrderFits`)
    /// and the one this pick makes does not, so renumbering never
    /// locks when nothing fits.
    func screenNumberFits(
        _ number: Int,
        for display: Display,
        anyFits: Bool
    ) -> Bool {
        guard anyFits,
            let next = screenOrder.renumbering(
                display.fingerprint,
                to: number
            )
        else { return true }
        return next.fits(
            config.settings.displayAreas,
            floors: config.settings.areaFloors
        )
    }
}
