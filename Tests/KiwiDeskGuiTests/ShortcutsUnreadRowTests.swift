import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A Lua-owned chord whose body could not be read back is still
/// listed (#2482): registered, so it blocks its chord, and a
/// panel that hid it would break "no bound shortcut is ever
/// invisible". `.serialized` mirrors the sibling suites
/// (`LocalizationManager` is a process-wide singleton).
@Suite("Shortcuts reference unread Lua rows (#2482)", .serialized)
@MainActor
struct ShortcutsUnreadRowTests {
    private func build(
        _ bindings: [KeyBinding],
        unread: [String]
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: bindings
            ),
            spaces: [SpaceID("1")],
            spaceIcons: [:],
            desktops: [1],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName],
            unread: unread
        )
    }

    @Test("an unread chord lists in Custom under the generic name")
    func unreadChordIsListed() {
        LocalizationManager.shared.select("en")
        let reference = build([], unread: ["ctrl+alt+u"])
        #expect(!reference.isEmpty)
        let row = reference.custom.first
        #expect(reference.custom.count == 1)
        #expect(row?.label == "Lua function")
        #expect(
            row?.combo
                == ShortcutsReferenceBuilder.glyphs("ctrl+alt+u")
        )
        #expect(row?.monospaced == false)
    }

    @Test("unread rows follow the readable Custom rows")
    func unreadFollowsReadable() {
        LocalizationManager.shared.select("en")
        let raw = KeyBinding(
            combo: "ctrl+alt+r",
            lua: "print(1)",
            kind: .custom
        )
        let reference = build([raw], unread: ["ctrl+alt+u"])
        #expect(
            reference.custom.map(\.label) == ["print(1)", "Lua function"]
        )
    }
}
