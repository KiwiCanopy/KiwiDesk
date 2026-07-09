import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The configurable resize step's GUI seam (#58): the catalog
/// authors `resize("x", ±step)` from the live setting, and import
/// classification matches a resize row of ANY magnitude by shape
/// (not the old byte-for-byte ±50), reading that magnitude back
/// into `resize.step`.
@MainActor
struct ResizeStepImportTests {
    private func customRow(_ lua: String) -> KeyBinding {
        KeyBinding(combo: "alt+h", lua: lua, kind: .custom)
    }

    private func config(luas: [String]) -> GuiConfig {
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: KeyMode.defaultName,
                bindings: luas.map(customRow)
            )
        ]
        return config
    }

    private func config(lua: String) -> GuiConfig {
        config(luas: [lua])
    }

    @Test("The catalog authors Grow/Shrink from the given step")
    func catalogAuthorsFromStep() {
        let rows = KeybindingCatalog.resizeAndFloat(step: 75)
        #expect(rows[0].lua == "KiwiDesk.resize(\"x\", -75)")
        #expect(rows[1].lua == "KiwiDesk.resize(\"x\", 75)")
    }

    @Test("A non-default resize magnitude still classifies")
    func nonDefaultMagnitudeClassifies() {
        var config = config(lua: "KiwiDesk.resize(\"x\", -75)")
        // Classification is not gated (only the step read-back is).
        KeybindingImportClassifier.classify(&config)
        let row = config.modes[0].bindings[0]
        // Old code demoted any non-±50 resize to Custom; now the
        // shape match upgrades it and keeps the canonical label.
        #expect(row.kind == .navigation)
        #expect(row.label == "Shrink")
    }

    @Test("Import reads the resize magnitude back into the step")
    func importReadsStepBack() {
        var config = config(lua: "KiwiDesk.resize(\"x\", 120)")
        #expect(config.settings.resizeStep == 50)
        KeybindingImportClassifier.classify(
            &config,
            recoverResizeStep: true
        )
        #expect(config.settings.resizeStep == 120)
        #expect(config.modes[0].bindings[0].label == "Enlarge")
    }

    @Test("A Shrink+Enlarge pair recovers one agreed magnitude")
    func pairRecoversStep() {
        var config = config(luas: [
            "KiwiDesk.resize(\"x\", -90)",
            "KiwiDesk.resize(\"x\", 90)",
        ])
        KeybindingImportClassifier.classify(
            &config,
            recoverResizeStep: true
        )
        #expect(config.settings.resizeStep == 90)
        #expect(config.modes[0].bindings[0].label == "Shrink")
        #expect(config.modes[0].bindings[1].label == "Enlarge")
    }

    @Test("A load-for-edit never overwrites the step")
    func loadForEditKeepsStep() {
        // Without `recoverResizeStep`, a resize row still
        // classifies but must not clobber the authoritative
        // setting (#58 review).
        var config = config(lua: "KiwiDesk.resize(\"x\", 120)")
        KeybindingImportClassifier.classify(&config)
        #expect(config.settings.resizeStep == 50)
        #expect(config.modes[0].bindings[0].kind == .navigation)
    }

    @Test("No resize row leaves the step at its default")
    func noResizeRowKeepsDefault() {
        var config = config(lua: "KiwiDesk.focus(\"left\")")
        KeybindingImportClassifier.classify(
            &config,
            recoverResizeStep: true
        )
        #expect(config.settings.resizeStep == 50)
    }

    @Test("A non-resize or malformed row is not a resize shape")
    func shapeRejectsNonResize() {
        #expect(
            KeybindingCatalog.resizeShape(
                from: "KiwiDesk.focus(\"left\")"
            ) == nil
        )
        // A zero delta is not a Grow or a Shrink.
        #expect(
            KeybindingCatalog.resizeShape(
                from: "KiwiDesk.resize(\"x\", 0)"
            ) == nil
        )
        // The y axis isn't authored yet (2-axis is #56).
        #expect(
            KeybindingCatalog.resizeShape(
                from: "KiwiDesk.resize(\"y\", 50)"
            ) == nil
        )
    }
}
