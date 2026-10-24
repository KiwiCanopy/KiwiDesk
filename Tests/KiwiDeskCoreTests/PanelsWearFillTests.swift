import AppKit
import Testing

@testable import KiwiDeskCore

/// **KiwiHub and the plates wear the Fill only where their glass
/// draws** (#2569 ▸ Ruling): the toggle, a Fill with colour, the
/// leaf they follow and the glass gate — Reduce transparency and the
/// platform — together, in one answer every reader takes.
@Suite("Panels wear the Fill (#2569)", .serialized)
@MainActor
struct PanelsWearFillTests {
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    private func settings(
        toggle: Bool = true,
        leaf: Bool = true,
        fill: String = "#14201CB3"
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = toggle
        settings.shortcutPanelLiquidGlass = leaf
        settings.kiwishelf.fillColor = fill
        return settings
    }

    @Test("Every term must hold")
    func everyTermHolds() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let before = LiquidGlassGate.override
        LiquidGlassGate.override = { false }
        defer { LiquidGlassGate.override = before }
        #expect(settings().panelsWearFill)
        #expect(!settings(toggle: false).panelsWearFill)
        #expect(!settings(leaf: false).panelsWearFill)
        #expect(!settings(fill: "#14201C00").panelsWearFill)
    }

    @Test("Reduce transparency stands it down")
    func reduceTransparencyStandsDown() {
        let before = LiquidGlassGate.override
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = before }
        #expect(!settings().panelsWearFill)
    }
}
