import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The GUI half of the advanced-track gate (#181): the core's
/// gated-binding set and the catalog rows must stay
/// byte-identical (registration skips exactly what the GUI
/// hides), and import classification stays UNgated — classify
/// always, render conditionally — or an import with the flag
/// off would silently demote track rows to Custom.
@MainActor
struct TrackAdvancedCatalogTests {
    @Test("Gated set matches the catalog rows byte-for-byte")
    func gatedSetMatchesCatalog() {
        #expect(
            Set(
                KeybindingCatalog.moveToTrackDirections
                    .map(\.lua)
            ) == TrackAdvancedBindings.gatedLua
        )
    }

    @Test("Import classifies gated rows with the flag off")
    func importClassificationUngated() {
        var config = GuiConfig()
        config.trackAdvanced = false
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+m",
                        lua:
                            "KiwiDesk.move_to_track(\"left\")",
                        kind: .custom,
                        label: ""
                    )
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.modes[0].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Move to the track to the left")
    }
}
