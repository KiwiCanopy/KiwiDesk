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
                rules: noRules,
                titlebarButton: false
            )
        )
        // Any accessory app, not just known bundle ids.
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "com.example.somelauncher",
                layer: 3,
                isAccessory: true,
                rules: noRules,
                titlebarButton: false
            )
        )
    }

    /// A buttoned window of a Dock-less app is one of its normal
    /// windows, not a launcher (#2072) — the escape is the
    /// accessory branch's alone; a layer-scoped bundle's raised
    /// window stays ignored with buttons.
    @Test("a buttoned accessory window escapes the ignore")
    func buttonedAccessoryWindowEscapes() {
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.apple.captivenetworkassistant",
                layer: 8,
                isAccessory: true,
                rules: noRules,
                titlebarButton: true
            )
        )
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "com.raycast.macos",
                layer: 8,
                isAccessory: false,
                rules: noRules,
                titlebarButton: true
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
                rules: noRules,
                titlebarButton: false
            )
        )
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.example.menubarapp",
                layer: 0,
                isAccessory: true,
                rules: noRules,
                titlebarButton: false
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
                rules: noRules,
                titlebarButton: false
            )
        )
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.raycast.macos",
                layer: 0,
                isAccessory: false,
                rules: noRules,
                titlebarButton: false
            )
        )
        // Raycast 2 (the "Raycast X" beta) has its own id.
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "com.raycast-x.macos",
                layer: 8,
                isAccessory: false,
                rules: noRules,
                titlebarButton: false
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
                rules: noRules,
                titlebarButton: false
            )
        )
    }

    /// A screen-saver-level window is a HUD or an overlay whatever
    /// its app (#2069): the line is the level itself, so one below
    /// it is still a regular app's float.
    @Test("any app's screen-saver-level window is never managed")
    func screenSaverLevelIgnored() {
        func ignored(_ layer: Int, button: Bool = false) -> Bool {
            FloatDetection.shouldIgnore(
                bundleID: "com.tinyspeck.slackmacgap",
                layer: layer,
                isAccessory: false,
                rules: noRules,
                titlebarButton: button
            )
        }
        let level = FloatDetection.screenSaverLayer
        #expect(ignored(level))
        #expect(ignored(level + 1, button: true))
        #expect(!ignored(level - 1))
    }

    /// The level refuses adoption, never a tracked window rising
    /// to it, whose removal the sweep would read as a close.
    @Test("a tracked window keeps its verdict from below the level")
    func trackedWindowIsJudgedBelowTheLevel() {
        let level = FloatDetection.screenSaverLayer
        #expect(FloatDetection.judgedLayer(level, tracked: false) == level)
        #expect(
            FloatDetection.judgedLayer(level + 1, tracked: true) == level - 1
        )
        #expect(FloatDetection.judgedLayer(8, tracked: true) == 8)
    }

    /// A focus report for a screen-saver-level window arms the
    /// ignored-panel distrust for any app, as the gate ignores it.
    @Test("an untracked screen-saver-level window is an ignored panel")
    func screenSaverLevelIsAPanel() {
        func panel(_ layer: Int) -> Bool {
            FloatDetection.isBuiltInIgnoredPanel(
                bundleID: "com.tinyspeck.slackmacgap",
                layer: layer,
                isAccessory: false,
                titlebarButton: false
            )
        }
        #expect(panel(FloatDetection.screenSaverLayer))
        #expect(!panel(FloatDetection.screenSaverLayer - 1))
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
