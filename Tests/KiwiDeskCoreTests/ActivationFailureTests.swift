import Foundation
import Testing

@testable import KiwiDeskCore

/// A registrar that refuses configured key codes — simulates
/// `RegisterEventHotKey` declining a system-reserved combo.
@MainActor
private final class DenyingRegistrar: HotkeyRegistrar {
    var deniedKeyCodes: Set<UInt32> = []
    private var nextID: UInt32 = 1
    private(set) var registered: Set<UInt32> = []

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        guard !deniedKeyCodes.contains(keyCode) else {
            return nil
        }
        let id = nextID
        nextID += 1
        registered.insert(id)
        return id
    }

    func unregister(id: UInt32) {
        registered.remove(id)
    }
}

/// `activationFailures` (#123): combos the system declined in
/// the most recent activation, so the GUI's live-apply can
/// branch its caption ("Active now" vs "the system didn't
/// grant it").
@Suite("Hotkey activation failures (#123)", .serialized)
@MainActor
struct ActivationFailureTests {
    @Test("Denied combos land in activationFailures")
    func deniedComboRecorded() throws {
        let registrar = DenyingRegistrar()
        let manager = KeybindingManager(registrar: registrar)
        let granted = try #require(KeyCombo.parse("cmd+j"))
        let denied = try #require(KeyCombo.parse("cmd+q"))
        registrar.deniedKeyCodes = [denied.keyCode]

        manager.bind(granted, ref: 1)
        manager.bind(denied, ref: 2)

        #expect(manager.activationFailures == [denied])
    }

    @Test("The next successful activation clears failures")
    func failuresClearOnReactivation() throws {
        let registrar = DenyingRegistrar()
        let manager = KeybindingManager(registrar: registrar)
        let denied = try #require(KeyCombo.parse("cmd+q"))
        registrar.deniedKeyCodes = [denied.keyCode]
        manager.bind(denied, ref: 1)
        #expect(manager.activationFailures == [denied])

        // The system frees the combo (or the user rebinds);
        // re-activating must not report a stale failure.
        registrar.deniedKeyCodes = []
        manager.switchMode(KeybindingManager.defaultMode)
        #expect(manager.activationFailures.isEmpty)
    }
}
