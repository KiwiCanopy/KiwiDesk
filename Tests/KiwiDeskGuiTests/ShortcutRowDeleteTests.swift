import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class DeleteRegistrar: HotkeyRegistrar {
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        return nextID
    }

    func unregister(id: UInt32) {}
}

/// Deleting a shortcut row must unregister its hotkey (#517).
/// The row's trash button removes it from the view's staged
/// `bindings` array, which the running hotkey table never sees —
/// `liveApplyRecorded` rebuilds from its own session copy — so
/// without an explicit `combo: nil` the shortcut kept firing
/// until Save or Revert.
///
/// The `remove(_:)` handlers themselves are private funcs inside
/// SwiftUI views and cannot be called from a test. What is
/// pinned here is the mechanism they now rely on: unregistering
/// works *after* the row is gone from the staged array, so the
/// fix's ordering is not accidental.
@Suite("Shortcut row deletion", .serialized)
@MainActor
struct ShortcutRowDeleteTests {
    private func makeModel() throws -> (SettingsModel, KiwiCore) {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-row-delete-\(UUID().uuidString)"
                ),
            hotkeyRegistrar: DeleteRegistrar()
        )
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: KeyMode.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "marker = 'keep'"
                    )
                ]
            )
        ]
        try core.saveGuiConfig(config)
        return (SettingsModel(core: core), core)
    }

    private func isRegistered(
        _ combo: String,
        core: KiwiCore
    ) throws -> Bool {
        let parsed = try #require(KeyCombo.parse(combo))
        return core.keys
            .bindings(for: KeyMode.defaultName)[parsed] != nil
    }

    /// Adds a live-registered row, then deletes it the way the
    /// trash button does: drop it from the staged array first,
    /// unregister second.
    @Test("deleting a row unregisters its hotkey")
    func deleteUnregisters() throws {
        let (model, core) = try makeModel()
        let mode = try #require(
            model.config.modes.firstIndex {
                $0.name == KeyMode.defaultName
            }
        )
        let added = KeyBinding(combo: "", lua: "marker = 'gone'")
        model.config.modes[mode].bindings.append(added)
        _ = model.liveApplyRecorded(
            modeName: KeyMode.defaultName,
            bindingID: added.id,
            combo: "alt+j"
        )
        #expect(try isRegistered("alt+j", core: core))

        model.config.modes[mode].bindings.removeAll {
            $0.id == added.id
        }
        _ = model.liveApplyRecorded(
            modeName: KeyMode.defaultName,
            bindingID: added.id,
            combo: nil
        )

        #expect(!(try isRegistered("alt+j", core: core)))
        // The untouched row must survive: the rebuild replaces
        // the whole table, so a botched unregister would take
        // every shortcut with it.
        #expect(try isRegistered("alt+h", core: core))
    }

    /// The gap the bug left: removing the row *without* the
    /// unregister leaves the hotkey live. Pinned so a future
    /// refactor that drops the call fails here rather than
    /// silently restoring the defect.
    @Test("removing without unregistering leaves it live")
    func removalAloneLeavesHotkeyLive() throws {
        let (model, core) = try makeModel()
        let mode = try #require(
            model.config.modes.firstIndex {
                $0.name == KeyMode.defaultName
            }
        )
        let added = KeyBinding(combo: "", lua: "marker = 'gone'")
        model.config.modes[mode].bindings.append(added)
        _ = model.liveApplyRecorded(
            modeName: KeyMode.defaultName,
            bindingID: added.id,
            combo: "alt+j"
        )

        model.config.modes[mode].bindings.removeAll {
            $0.id == added.id
        }

        #expect(try isRegistered("alt+j", core: core))
    }

    /// Off the live target nothing is registered, so the delete
    /// path must be a no-op rather than an error.
    @Test("no-op while editing a stored profile")
    func storedProfileDeleteIsNoOp() throws {
        let (model, _) = try makeModel()
        model.target = .storedProfile("whatever")
        let feedback = model.liveApplyRecorded(
            modeName: KeyMode.defaultName,
            bindingID: UUID(),
            combo: nil
        )
        #expect(feedback == nil)
    }
}
