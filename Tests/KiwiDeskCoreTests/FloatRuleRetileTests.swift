import CoreGraphics
import Testing

@testable import KiwiDeskCore

// Float rules and the retile filter, split out of
// LayoutMiscTests.swift to keep both files under the 350-line
// ceiling (AGENTS.md §5, issue #560).

private let w1 = WindowID(1)

@Suite("Float rules and retile filter")
struct FloatRuleTests {
    @Test("App rule floats every window of the app")
    func appRule() throws {
        let rules = FloatRules(["com.apple.calculator"])
        #expect(
            rules.matches(
                bundleID: "com.apple.calculator",
                title: "X"
            )
        )
        #expect(
            !rules.matches(
                bundleID: "com.apple.finder",
                title: "X"
            )
        )
    }

    @Test("Bundle id match is case-insensitive")
    func caseInsensitive() throws {
        // Rules ingest and store lower-cased; a query in any
        // case still matches (LaunchServices semantics) — the
        // matcher normalizes both the stored rule and the query.
        let rules = FloatRules(["com.apple.Calculator"])
        #expect(
            rules.matches(
                bundleID: "com.apple.calculator",
                title: "X"
            )
        )
        #expect(
            rules.matches(
                bundleID: "com.apple.CALCULATOR",
                title: "X"
            )
        )
        #expect(
            rules.hasTitleRule(bundleID: "COM.APPLE.CALCULATOR")
                == false
        )
    }

    @Test("A nil bundle id matches no rule")
    func nilBundleID() throws {
        let rules = FloatRules(["com.apple.calculator"])
        #expect(!rules.matches(bundleID: nil, title: "X"))
        #expect(!rules.hasTitleRule(bundleID: nil))
    }

    @Test("App:Title rule needs the title fragment")
    func titleRule() throws {
        let rules = FloatRules(["com.apple.finder:Get Info"])
        #expect(
            rules.matches(
                bundleID: "com.apple.finder",
                title: "Report.pdf Get Info"
            )
        )
        #expect(
            !rules.matches(
                bundleID: "com.apple.finder",
                title: "Desktop"
            )
        )
    }

    @Test("Non-standard subroles float by default")
    func subroleDetection() throws {
        #expect(
            FloatDetection.shouldFloat(
                role: "AXWindow",
                subrole: "AXDialog"
            )
        )
        #expect(
            FloatDetection.shouldFloat(
                role: "AXSheet",
                subrole: ""
            )
        )
        #expect(
            !FloatDetection.shouldFloat(
                role: "AXWindow",
                subrole: "AXStandardWindow"
            )
        )
    }

    @Test("Non-normal window layers float despite the subrole")
    func layerDetection() throws {
        // Ghostty's quick terminal: layer 3, but can read as
        // AXStandardWindow during the startup scan.
        #expect(
            FloatDetection.shouldFloat(
                role: "AXWindow",
                subrole: "AXStandardWindow",
                layer: 3
            )
        )
        #expect(
            !FloatDetection.shouldFloat(
                role: "AXWindow",
                subrole: "AXStandardWindow",
                layer: 0
            )
        )
    }

    @Test("Ghostty's quick terminal panel is never managed")
    func ignoreDetection() throws {
        let noRules = IgnoreRules()
        // The quick terminal: Ghostty + non-zero layer.
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "com.mitchellh.ghostty",
                layer: 3,
                isAccessory: false,
                rules: noRules
            )
        )
        // Ghostty's normal windows tile as usual.
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.mitchellh.ghostty",
                layer: 0,
                isAccessory: false,
                rules: noRules
            )
        )
        // Other regular apps' panels merely float; the ignore
        // is layer-scoped per app (#21) or accessory-wide
        // (#448), never blanket raised-layer.
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.apple.finder",
                layer: 3,
                isAccessory: false,
                rules: noRules
            )
        )
    }

    @Test("User ignore rules match whole apps by bundle id")
    func userIgnoreRules() {
        let rules = IgnoreRules(["IO.TAILSCALE.IPN.MACOS"])
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "io.tailscale.ipn.macos",
                layer: 0,
                isAccessory: false,
                rules: rules
            )
        )
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "io.tailscale.ipn.macos",
                layer: 9,
                isAccessory: true,
                rules: rules
            )
        )
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.apple.finder",
                layer: 0,
                isAccessory: false,
                rules: rules
            )
        )
    }

    @Test("macOS input-source overlays are never managed")
    func systemInputOverlays() {
        for bundleID in [
            "com.apple.TextInputMenuAgent",
            "com.apple.TextInputSwitcher",
            "com.apple.controlcenter",
        ] {
            #expect(
                FloatDetection.isBuiltInIgnoredApp(
                    bundleID: bundleID
                )
            )
            #expect(
                FloatDetection.shouldIgnore(
                    bundleID: bundleID,
                    layer: 0,
                    isAccessory: false,
                    rules: IgnoreRules()
                )
            )
        }
        #expect(
            !FloatDetection.isBuiltInIgnoredApp(
                bundleID: "com.apple.finder"
            )
        )
    }

    @Test("Unbacked AX auxiliary proxies are never managed")
    func unbackedAuxiliaryProxies() {
        #expect(
            FloatDetection.isUnbackedAuxiliary(
                role: "AXWindow",
                subrole: "AXFloatingWindow",
                layer: nil
            )
        )
        #expect(
            !FloatDetection.isUnbackedAuxiliary(
                role: "AXWindow",
                subrole: "AXFloatingWindow",
                layer: 0
            )
        )
        #expect(
            !FloatDetection.isUnbackedAuxiliary(
                role: "AXWindow",
                subrole: "AXStandardWindow",
                layer: nil
            )
        )
    }

    @Test("Only structural events trigger a retile")
    func retileFilter() throws {
        #expect(
            TilingEngine.shouldRetile(
                after: .windowDestroyed(
                    w1,
                    wasMinimized: false
                )
            )
        )
        // A healed float verdict changes layout membership.
        #expect(
            TilingEngine.shouldRetile(
                after: .windowFloatChanged(
                    w1,
                    isFloating: true
                )
            )
        )
        // Focus retiles are gated by the layout mode instead
        // (only Scrolling and Monocle are focus-driven).
        #expect(
            !TilingEngine.shouldRetile(
                after: .windowFocused(w1)
            )
        )
        #expect(LayoutMode.scrolling.isFocusDriven)
        #expect(LayoutMode.monocle.isFocusDriven)
        #expect(!LayoutMode.stack.isFocusDriven)
        #expect(!LayoutMode.bsp.isFocusDriven)
        #expect(
            !TilingEngine.shouldRetile(
                after: .windowMoved(w1, .zero)
            )
        )
        #expect(
            !TilingEngine.shouldRetile(
                after: .windowTitleChanged(w1, "t")
            )
        )
    }
}
