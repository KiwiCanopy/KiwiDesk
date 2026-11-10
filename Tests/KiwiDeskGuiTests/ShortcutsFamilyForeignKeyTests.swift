import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A key from another area is no Shortcuts family, split from
/// `ShortcutsFamilyRowsTests` at the file ceiling.
@Suite("Shortcuts family foreign keys")
struct ShortcutsFamilyForeignKeyTests {

    /// A census key from ANOTHER area carries no keybinding
    /// rows. Pinned because `nil` here means two different
    /// things — a hand-drawn Shortcuts container, or a key that
    /// was never a shortcut — and only the second is checkable
    /// by kind.
    @Test("a key from another area carries no keybinding rows")
    @MainActor
    func foreignKeyIsNotAFamily() {
        #expect(
            fixture().rows(for: .behaviour(.minWindowSize)) == nil
        )
        #expect(fixture().rows(for: .general(.language)) == nil)
    }

    /// Pins the display-independent inputs every expansion
    /// reasons from, so a default that moves reds as a default
    /// rather than as a mysterious count.
    @MainActor
    private func fixture() -> ShortcutsFamilyRows {
        ShortcutsFamilyRows(
            spaces: ["1", "2", "mail"],
            icons: [:],
            desktops: KeybindingCatalog.DesktopOffer(desktops: [1, 2]),
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName, "resize"],
            currentLayer: KeyLayer.defaultName,
            lenses: ["Writing"]
        )
    }
}
