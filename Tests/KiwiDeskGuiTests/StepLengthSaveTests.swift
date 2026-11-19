import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Step length slider's value reaches gui.json (#3505): on a desk
/// with profiles the live page writes its scroll base through the
/// reach snapshot, which holds every field but the global-only
/// `step_length`, so the draft's value must be carried over it.
@Suite("Step length save", .serialized)
@MainActor
struct StepLengthSaveTests {
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    @Test("a slider edit is saved to gui.json")
    func sliderEditIsSaved() throws {
        let model = try makeModel()
        let stored = ScrollGestureBase.defaults.stepLength
        #expect(model.config.scrollGesture.stepLength == stored)
        model.config.scrollGesture.stepLength = 9.5
        #expect(model.sidecarConfig.scrollGesture.stepLength == 9.5)
        model.updateActiveProfile()
        #expect(
            model.core.guiConfigStore.load()?.scrollGesture.stepLength
                == 9.5
        )
    }
}
