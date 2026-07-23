import Testing

@testable import KiwiDeskCore

/// Auto-ignore for Spotlight/Raycast-style command bars (#448):
/// a third-party accessory app's raised-layer window is a
/// transient overlay that must never be managed — merely
/// floating it still pins it to a space and drags it across
/// space switches. Layer-0 accessory windows (settings,
/// pickers) stay managed floats.
@Suite("Command-bar auto-ignore")
struct CommandBarIgnoreTests {
    private let noRules = IgnoreRules()

    @Test("Accessory raised-layer windows are never managed")
    func accessoryPanelIgnored() {
        // Raycast/Spotlight-shaped: accessory app, raised layer.
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "com.raycast.macos",
                layer: 8,
                isAccessory: true,
                rules: noRules
            )
        )
        // Any accessory app, not just known bundle ids.
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "com.example.somelauncher",
                layer: 3,
                isAccessory: true,
                rules: noRules
            )
        )
    }

    @Test("Accessory layer-0 windows stay managed floats")
    func accessoryNormalWindowTracked() {
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.raycast.macos",
                layer: 0,
                isAccessory: true,
                rules: noRules
            )
        )
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.example.menubarapp",
                layer: 0,
                isAccessory: true,
                rules: noRules
            )
        )
    }

    @Test("Raycast is layer-scoped even as a regular app")
    func raycastBeltWithoutAccessoryPolicy() {
        // Raycast configured to show a dock icon loses the
        // accessory policy; the bundle belt still catches its
        // command bar.
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "com.raycast.macos",
                layer: 8,
                isAccessory: false,
                rules: noRules
            )
        )
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.raycast.macos",
                layer: 0,
                isAccessory: false,
                rules: noRules
            )
        )
        // Raycast 2 (the "Raycast X" beta) has its own id.
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "com.raycast-x.macos",
                layer: 8,
                isAccessory: false,
                rules: noRules
            )
        )
    }

    @Test("Regular apps' raised-layer panels only float")
    func regularAppPanelsNotIgnored() {
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.apple.finder",
                layer: 8,
                isAccessory: false,
                rules: noRules
            )
        )
    }

    @Test("The visible-panel scan counts only the panel band")
    func panelBandExcludesStatusItems() {
        // Command bars and quick terminals: floating (3) up to
        // modal panel (8).
        #expect(FloatDetection.isPanelBandLayer(3))
        #expect(FloatDetection.isPanelBandLayer(8))
        // A menu-bar app's permanent NSStatusItem window (25)
        // or a popped menu (101) must never read as a visible
        // ignored panel — that would distrust every accessory
        // app's focus reports forever.
        #expect(!FloatDetection.isPanelBandLayer(0))
        #expect(!FloatDetection.isPanelBandLayer(24))
        #expect(!FloatDetection.isPanelBandLayer(25))
        #expect(!FloatDetection.isPanelBandLayer(101))
        // Desktop-level backdrops (wallpaper utilities) sit
        // BELOW normal — the band is strictly raised.
        #expect(
            !FloatDetection.isPanelBandLayer(-2_147_483_623)
        )
    }

    @Test("Layer scan required for accessory and listed apps")
    func requiresWindowLayers() {
        #expect(
            FloatDetection.requiresWindowLayers(
                bundleID: "com.example.somelauncher",
                isAccessory: true
            )
        )
        #expect(
            FloatDetection.requiresWindowLayers(
                bundleID: "com.raycast.macos",
                isAccessory: false
            )
        )
        #expect(
            FloatDetection.requiresWindowLayers(
                bundleID: "com.mitchellh.ghostty",
                isAccessory: false
            )
        )
        #expect(
            !FloatDetection.requiresWindowLayers(
                bundleID: "com.apple.finder",
                isAccessory: false
            )
        )
    }
}
