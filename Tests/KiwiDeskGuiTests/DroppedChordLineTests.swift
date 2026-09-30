import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Shortcuts header's left-out line names the kept action by
/// its LOCALIZED row label (#1807): the stored label is the English
/// identifier, and a translated sentence around it read wrong.
@Suite("Dropped chord line (#1807)", .serialized)
@MainActor
struct DroppedChordLineTests {
    @Test("the kept action is named in the reader's language")
    func labelIsLocalized() {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select(nil) }
        var config = GuiConfig()
        config.spaces = [SpaceID("5")]
        let label = "Go to Space 5"
        let entry = NavigationChords.Dropped(
            dropped: KeyBinding(
                combo: "control+option+f5",
                lua: "KiwiDesk.focus_space(\"5\")",
                kind: .navigation,
                label: label
            ),
            kept: KeyBinding(
                combo: "control+option+5",
                lua: "KiwiDesk.focus_space(\"5\")",
                kind: .navigation,
                label: label
            )
        )
        let localized = KeybindingCatalog.localizedLabel(
            for: label,
            config: config
        )
        // Vacuity: German names this row differently.
        #expect(localized != label)
        let line = ShortcutsHeader.droppedLine(entry, config: config)
        #expect(line.contains(localized))
        #expect(!line.contains(label))
    }
}
