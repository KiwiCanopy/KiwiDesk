import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The visible-panel scan states the title-bar button like every
/// other reader of the ignore predicate (#2344): an untracked
/// buttoned window the gate would admit is no panel, and the
/// button is asked only where `needsTitlebarButton` says it
/// decides. The wiring that hands the scan the event loop's
/// reader is `VisiblePanelWiringTests`'.
@Suite("Visible-panel scan reads the button")
struct VisiblePanelButtonTests {
    private let window = WindowID(900_101)

    /// One listed window's verdict, and the ids whose button the
    /// scan asked for.
    private func panel(
        _ id: WindowID?,
        layer: Int = 8,
        bundleID: String = "com.example.menubarapp",
        accessory: Bool = true,
        tracked: Set<WindowID> = [],
        buttoned: Set<WindowID> = []
    ) -> (panel: Bool, asked: [WindowID]) {
        var asked: [WindowID] = []
        let verdict = FloatDetection.isVisibleIgnoredPanel(
            id: id,
            layer: layer,
            bundleID: bundleID,
            isAccessory: accessory,
            tracked: tracked,
            titlebarButton: {
                asked.append($0)
                return buttoned.contains($0)
            }
        )
        return (verdict, asked)
    }

    @Test("an accessory app's buttoned window is no panel")
    func buttonedAccessoryWindowEscapes() {
        #expect(panel(window).panel)
        #expect(panel(window).asked == [window])
        #expect(!panel(window, buttoned: [window]).panel)
    }

    @Test("a tracked, unbanded or unnumbered window asks nothing")
    func buttonAskedOnlyForACandidate() {
        #expect(!panel(window, tracked: [window]).panel)
        #expect(panel(window, tracked: [window]).asked.isEmpty)
        #expect(!panel(window, layer: 0).panel)
        #expect(panel(window, layer: 0).asked.isEmpty)
        // A status item or popped menu sits at or above the
        // main-menu level, outside the band the scan counts (#448).
        let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        #expect(!panel(window, layer: menuLevel).panel)
        #expect(panel(window, layer: menuLevel).asked.isEmpty)
        #expect(panel(nil).panel)
        #expect(panel(nil).asked.isEmpty)
    }

    @Test("Raycast takes no escape, so its button is never read")
    func raycastIsNeverAsked() {
        let raycast = panel(
            window,
            bundleID: "com.raycast.macos",
            accessory: false,
            buttoned: [window]
        )
        #expect(raycast.panel)
        #expect(raycast.asked.isEmpty)
    }

    /// Below the modal-panel level, where Ghostty's escape rides
    /// the button alone (#2067, #2200).
    @Test("Ghostty's buttoned window escapes as the gate's does")
    func ghosttyEscapesWithAButton() {
        func ghostty(_ buttoned: Set<WindowID>) -> (Bool, [WindowID]) {
            panel(
                window,
                layer: 3,
                bundleID: "com.mitchellh.ghostty",
                accessory: false,
                buttoned: buttoned
            )
        }
        #expect(ghostty([]).0)
        #expect(!ghostty([window]).0)
        #expect(ghostty([window]).1 == [window])
    }
}
