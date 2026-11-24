import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Restore Defaults rebuilds the seed the first run wrote, so its
/// undo pair sits on the key that types "z" on the active layout
/// too (#3599), never the US Z position.
@Suite("Restore Defaults seeds undo by letter (#3599)")
@MainActor
struct RestoreUndoKeyTests {
    @Test("the restored seed takes the layout's Z")
    func restoreReadsTheLayout() {
        let core = makeTestCore()
        // German QWERTZ: "z" is key code 16, `KeyCombo`'s `y`.
        core.keyCodeTyping = { $0 == "z" ? 16 : KeyCombo.keyCodes[$0] }
        let model = makeTestModel(core: core)
        let shipped = model.shippedDefaults(on: .standard)
        let undo = shipped.first { $0.lua == "KiwiDesk.undo_layout()" }
        let redo = shipped.first { $0.lua == "KiwiDesk.redo_layout()" }
        #expect(undo?.combo == "control+option+y")
        #expect(redo?.combo == "control+option+shift+y")
    }
}
