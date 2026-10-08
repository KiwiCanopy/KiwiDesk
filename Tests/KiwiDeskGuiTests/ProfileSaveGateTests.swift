import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class GateRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// The footer blocks any profile save that captures the live
/// monitor set while Accessibility is off — a paused engine has
/// discovered no displays, so persisting would record a
/// degenerate 0-screen set that never resolves (#335). The gate
/// is the model's `profileSaveBlockedReason`.
@Suite("Profile save gate while paused", .serialized)
@MainActor
struct ProfileSaveGateTests {
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(
            hotkeyRegistrar: GateRegistrar()
        )
        try core.saveGuiConfig(GuiConfig())
        return makeTestModel(core: core)
    }

    @Test("no reason when Accessibility is granted")
    func unblockedWhenActive() throws {
        let model = try makeModel()
        model.coreHold = .running
        #expect(model.profileSaveBlockedReason == nil)
    }

    @Test("blocked with a reason while paused")
    func blockedWhilePaused() throws {
        let model = try makeModel()
        model.coreHold = .permissionMissing
        #expect(model.profileSaveBlockedReason != nil)
    }

    /// Before Start Tiling the core never ran, so no screen is
    /// known either (#2050) — the same gate, its own reason.
    @Test("blocked with its own reason before Start Tiling")
    func blockedWhileNotStarted() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.coreHold = .notStarted
        let reason = try #require(model.profileSaveBlockedReason)
        #expect(reason.hasPrefix("KiwiDesk isn't tiling yet"))
    }

    @Test("a global edit before Start Tiling saves globals only")
    func notStartedGlobalEditSavesGlobals() throws {
        let model = try makeModel()
        model.coreHold = .notStarted
        model.config.appRules["com.example.app"] = SpaceID("2")
        #expect(model.globalsChanged)
        #expect(model.primarySaveAction == .saveGlobalsOnly)
    }
}
