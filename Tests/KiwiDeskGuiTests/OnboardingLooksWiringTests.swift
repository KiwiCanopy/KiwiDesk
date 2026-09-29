import Foundation
import Testing

/// The looks step's blocker and follow live in wiring the model
/// tests stub out (#1720): the draft read that greys the step, the
/// Settings re-read Core's `onLiveProfileWritten` reaches, and the reload
/// inside it. Each needle is keyed on its use site.
@Suite("Onboarding looks wiring (#1720)")
struct OnboardingLooksWiringTests {
    private func source(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/" + path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
    }

    @Test("the step reads the Settings draft it must not overwrite")
    func draftIsRead() throws {
        let wiring = try source("AppDelegate+OnboardingLooks.swift")
        #expect(
            wiring.contains(
                "onboardingModel.settingsDraftPending = { [weak self] in\n"
                    + "            self?.dashboardIfCreated?.hasUnsavedDraft"
            )
        )
        let controller = try source(
            "Settings/SettingsWindowController.swift"
        )
        #expect(
            controller.contains(
                "var hasUnsavedDraft: Bool { model.isDirty && "
                    + "model.target == .live }"
            )
        )
    }

    @Test("every paint re-reads a clean Settings draft")
    func paintFollowsIntoSettings() throws {
        let delegate = try source("AppDelegate.swift")
        #expect(
            delegate.contains(
                "core.onLiveProfileWritten = { [weak self] "
                    + "edit, persisted in\n"
                    + "            self?.dashboardIfCreated?.adoptLiveWrite(\n"
                    + "                edit,\n"
                    + "                persisted: persisted"
            )
        )
        let model = try source("Settings/SettingsModel+LiveWrite.swift")
        #expect(
            model.contains(
                "guard isDirty else {\n            reload()"
            )
        )
    }
}
