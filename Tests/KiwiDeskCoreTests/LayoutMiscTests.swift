import CoreGraphics
import Testing

@testable import KiwiDeskCore

// Non-grid layout tests split out of GridLayoutTests to keep both
// files under the 350-line ceiling (AGENTS.md §5): the layout
// dispatcher, monocle/floating basics, gap geometry, and the
// float-rule / retile filter.

private let w1 = WindowID(1)

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
) -> LayoutContext {
    LayoutContext(bounds: bounds, gaps: .uniform(10))
}

@Suite("Monocle and Floating")
struct SimpleLayoutTests {
    @Test("Monocle maximizes every window (bar disabled)")
    func monocle() throws {
        // The default-on indicator bar carves its strip out
        // of the usable area; without it, monocle fills the
        // whole thing (see MonocleTests for the strip).
        var context = makeContext()
        context.monocle.appBar.enabled = false
        let frames = MonocleLayout().calculateGeometry(
            for: ids(3),
            in: context
        )
        for frame in frames.values {
            #expect(frame == context.usable)
        }
    }

    @Test("Floating manages nothing")
    func floating() throws {
        let frames = FloatingLayout().calculateGeometry(
            for: ids(3),
            in: makeContext()
        )
        #expect(frames.isEmpty)
    }

    @Test("Dispatcher returns the matching system")
    func dispatch() throws {
        #expect(
            LayoutEngine.system(for: .bsp) is BspLayout
        )
        #expect(
            LayoutEngine.system(for: .monocle)
                is MonocleLayout
        )
        #expect(
            LayoutEngine.system(for: .floating)
                is FloatingLayout
        )
    }
}

@Suite("Gaps and geometry")
struct GapsGeometryTests {
    @Test("Per-edge outer gaps shape the usable area")
    func perEdgeOuter() throws {
        var gaps = Gaps()
        gaps.outer = Gaps.Outer(
            top: 5,
            bottom: 20,
            left: 10,
            right: 15
        )
        let context = LayoutContext(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            ),
            gaps: gaps
        )
        #expect(
            context.usable
                == CGRect(
                    x: 10,
                    y: 5,
                    width: 1895,
                    height: 1055
                )
        )
    }

    @Test("Uniform helper sets all six gaps")
    func uniform() throws {
        let gaps = Gaps.uniform(8)
        #expect(gaps.outer.top == 8)
        #expect(gaps.outer.right == 8)
        #expect(gaps.inner.horizontal == 8)
        #expect(gaps.inner.vertical == 8)
    }

    @Test("Coordinate flip is its own inverse")
    func flipInvolution() throws {
        let rect = CGRect(x: 100, y: 200, width: 400, height: 300)
        let flipped = GeometryUtils.flip(
            rect,
            primaryHeight: 1080
        )
        #expect(flipped.minY == 1080 - rect.maxY)
        let back = GeometryUtils.flip(
            flipped,
            primaryHeight: 1080
        )
        #expect(back == rect)
    }
}

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
                rules: noRules
            )
        )
        // Ghostty's normal windows tile as usual.
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.mitchellh.ghostty",
                layer: 0,
                rules: noRules
            )
        )
        // Other apps' panels merely float; only Ghostty's
        // quick terminal is ignored outright (issue #21).
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.apple.finder",
                layer: 3,
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
                rules: rules
            )
        )
        #expect(
            FloatDetection.shouldIgnore(
                bundleID: "io.tailscale.ipn.macos",
                layer: 9,
                rules: rules
            )
        )
        #expect(
            !FloatDetection.shouldIgnore(
                bundleID: "com.apple.finder",
                layer: 0,
                rules: rules
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
