import Testing

@testable import KiwiDeskCore

/// **KiwiHub and the plates wear the Fill only where their glass
/// draws** (#2569 ▸ Ruling): the toggle, a Fill with colour and
/// their leaf as drawn, together, in one answer every reader takes.
/// The answer is pure; each tree hands it its own read of the gate.
@Suite("Panels wear the Fill (#2569)")
struct PanelsWearFillTests {
    private func settings(
        toggle: Bool = true,
        fill: String = "#14201CB3"
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = toggle
        settings.kiwishelf.fillColor = fill
        return settings
    }

    @Test("Every term must hold")
    func everyTermHolds() {
        #expect(settings().panelsWearFill(glassDrawn: true))
        #expect(!settings().panelsWearFill(glassDrawn: false))
        #expect(!settings(toggle: false).panelsWearFill(glassDrawn: true))
        #expect(
            !settings(fill: "#14201C00").panelsWearFill(glassDrawn: true)
        )
    }
}
