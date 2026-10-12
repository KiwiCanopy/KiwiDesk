import Testing

@testable import KiwiDeskCore

/// Ghostty's belt ignores its raised windows only without a
/// title-bar button (#2067): the quick terminal has none at either
/// layer it takes (3 shown, 101 hidden), its config-error window
/// has them. Raycast's belt is untouched.
@Suite("Ghostty button escape (#2067)")
struct GhosttyButtonEscapeTests {
    private static let ghostty = "com.mitchellh.ghostty"

    private func ignored(
        _ bundleID: String,
        layer: Int,
        button: Bool,
        accessory: Bool = false
    ) -> Bool {
        FloatDetection.shouldIgnore(
            bundleID: bundleID,
            layer: layer,
            isAccessory: accessory,
            rules: IgnoreRules(),
            titlebarButton: button
        )
    }

    @Test("the quick terminal stays ignored; a buttoned window is kept")
    func ghosttyEscapesWithAButton() {
        #expect(ignored(Self.ghostty, layer: 3, button: false))
        #expect(ignored(Self.ghostty, layer: 101, button: false))
        #expect(!ignored(Self.ghostty, layer: 101, button: true))
        #expect(!ignored(Self.ghostty, layer: 0, button: false))
    }

    @Test("Raycast's belt ignores a buttoned window as before")
    func raycastKeepsItsBelt() {
        #expect(ignored("com.raycast.macos", layer: 8, button: true))
        #expect(
            ignored(
                "com.raycast.macos",
                layer: 8,
                button: true,
                accessory: true
            )
        )
    }

    /// The gate asks the button wherever the escape decides, so
    /// every reader reads one for a raised Ghostty window.
    @Test("a raised Ghostty window asks its button")
    func ghosttyAsksTheButton() {
        #expect(
            FloatDetection.needsTitlebarButton(
                layer: 101,
                isAccessory: false,
                bundleID: Self.ghostty
            )
        )
        #expect(
            !FloatDetection.needsTitlebarButton(
                layer: 0,
                isAccessory: false,
                bundleID: Self.ghostty
            )
        )
        #expect(
            !FloatDetection.needsTitlebarButton(
                layer: 8,
                isAccessory: false,
                bundleID: "com.raycast.macos"
            )
        )
    }
}
