import AppKit
import Testing

@testable import KiwiDeskCore

/// Which reason detection gives a float (#1810) — the value a Tile
/// refusal's pill and the bar menu's greyed row both show. The
/// suites of the refusal hand the verdict in, so a swapped reason
/// is caught here or nowhere.
@Suite("Auto-float reason (#1810)")
struct AutoFloatReasonTests {
    /// A dialog a rule also matches is a panel: deleting the rule
    /// would not tile it, so the pill must not send you there.
    @Test("structure outranks a rule, and a panel skips the rule read")
    func structureFirst() {
        var asked = false
        #expect(
            FloatDetection.autoFloatReason(structural: true) {
                asked = true
                return true
            } == .panel
        )
        #expect(!asked)
        #expect(
            FloatDetection.autoFloatReason(structural: false) { true }
                == .rule
        )
        #expect(
            FloatDetection.autoFloatReason(structural: false) { false }
                == nil
        )
    }

    /// A fixed size is asked last, only where nothing else floats
    /// the window, and only of a standard normal-layer window
    /// (#2070): a sheet or panel reads its own reason, a zoom
    /// button that did not answer tiles.
    @Test("a fixed-size standard window floats, asked last")
    func fixedSizeLast() {
        var asked = false
        #expect(
            FloatDetection.autoFloatReason(
                structural: false,
                ruleMatches: { true },
                fixedSize: {
                    asked = true
                    return true
                }
            ) == .rule
        )
        #expect(!asked)
        func facts(
            _ subrole: String,
            layer: Int = 0,
            zoomable: Bool?
        ) -> WindowFacts {
            WindowFacts(
                role: kAXWindowRole,
                subrole: subrole,
                layer: layer,
                zoomable: { zoomable }
            ) { "Settings" }
        }
        let standard = kAXStandardWindowSubrole
        let reason = { (facts: WindowFacts) in
            FloatDetection.autoFloatReason(
                facts,
                bundleID: "com.apple.mail",
                rules: FloatRules()
            )
        }
        #expect(reason(facts(standard, zoomable: false)) == .fixedSize)
        #expect(reason(facts(standard, zoomable: true)) == nil)
        #expect(reason(facts(standard, zoomable: nil)) == nil)
        #expect(
            reason(facts(kAXDialogSubrole, zoomable: false)) == .panel
        )
    }

    @Test("a third-party app with no Dock icon is the accessory reason")
    func accessoryApp() {
        #expect(
            EventLoop.forceFloatReason(
                pid: 1,
                activationPolicy: .accessory,
                tilesAsOwnWindow: false
            ) == .accessoryApp
        )
        #expect(
            EventLoop.forceFloatReason(
                pid: 1,
                activationPolicy: .regular,
                tilesAsOwnWindow: false
            ) == nil
        )
    }

    /// Own chrome is a panel, read through the mark's seam; the
    /// marked Settings window has no reason at all.
    @MainActor
    @Test("own chrome is a panel; the marked own window has none")
    func ownChrome() {
        let loop = EventLoop()
        let id = WindowID(4243)
        loop.ownWindowIdentifier = { _ in nil }
        #expect(loop.forceFloatReason(pid: getpid(), id: id) == .panel)
        loop.ownWindowIdentifier = { _ in OwnWindowTiling.identifier }
        #expect(loop.forceFloatReason(pid: getpid(), id: id) == nil)
    }

    @Test("a verdict floats exactly when it carries a reason")
    func verdictShape() {
        #expect(!FloatVerdict(nil).floats)
        #expect(FloatVerdict(.rule) == .floats(.rule))
        #expect(FloatVerdict(.panel).reason == .panel)
    }
}
