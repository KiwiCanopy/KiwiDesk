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
@Suite("Profile save gate while paused")
@MainActor
struct ProfileSaveGateTests {
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(
            hotkeyRegistrar: GateRegistrar()
        )
        try core.saveGuiConfig(GuiConfig())
        return SettingsModel(core: core)
    }

    @Test("no reason when Accessibility is granted")
    func unblockedWhenActive() throws {
        let model = try makeModel()
        model.permissionPaused = false
        #expect(model.profileSaveBlockedReason == nil)
    }

    @Test("blocked with a reason while paused")
    func blockedWhilePaused() throws {
        let model = try makeModel()
        model.permissionPaused = true
        #expect(model.profileSaveBlockedReason != nil)
    }
}
