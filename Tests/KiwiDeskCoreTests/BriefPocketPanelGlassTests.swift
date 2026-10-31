import AppKit
import Testing

@testable import KiwiDeskCore

/// The brief pocket's flying plate is the Space switch's plate, so
/// its panel wears the key-window rim while the plate wears the
/// Fill, as the slide's does (#2569). Asserts the panel a real play
/// presents, so a play that stops setting the switch reds here.
@Suite(
    "Brief pocket plate wears the active look (#2569)",
    .enabled(if: !NSScreen.screens.isEmpty)
)
@MainActor
struct BriefPocketPanelGlassTests {
    private func presentedPanel(tint: GlassFill?) throws -> NSPanel {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplayID)
        let overlay = BriefPocketOverlay()
        var presented: NSPanel?
        overlay.present = { presented = $0 }
        overlay.makeFrames = { _, _ in nil }
        overlay.icon = { _ in nil }
        defer { overlay.end() }
        overlay.play(
            BriefPocketOverlay.Request(
                display: display,
                screen: screen,
                direction: .into,
                window: CGRect(x: 100, y: 100, width: 400, height: 300),
                pocket: CGRect(x: 20, y: 20, width: 32, height: 32),
                iconPid: nil,
                markHex: "",
                plateGlass: true,
                plateTint: tint,
                flight: 0.3
            )
        )
        return try #require(presented, "the play presents its panel")
    }

    @Test("a tinted plate's panel wears the rim", arguments: [true, false])
    func panelFollowsTheTint(tinted: Bool) throws {
        let panel = try presentedPanel(
            tint: tinted ? GlassFill(hex: "#14201CB3") : nil
        )
        let active = panel as? ActiveGlassPanel
        #expect(active != nil, "the plate's panel answers the question")
        #expect(active?.wearsActiveLook == tinted)
    }
}
