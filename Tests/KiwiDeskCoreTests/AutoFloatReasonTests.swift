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
            FloatDetection.autoFloatReason(
                structural: .panel,
                fixedSize: { false }
            ) {
                asked = true
                return true
            } == .panel
        )
        #expect(!asked)
        #expect(
            FloatDetection.autoFloatReason(
                structural: nil,
                fixedSize: { false }
            ) { true } == .rule
        )
        #expect(
            FloatDetection.autoFloatReason(
                structural: nil,
                fixedSize: { false }
            ) { false } == nil
        )
    }

    /// A fixed size is what no setting removes, like structure: a
    /// rule matching the same window must not send you to App
    /// Rules, whose deletion would not tile it (#2070). It is asked
    /// only of a standard normal-layer window, and a zoom button
    /// that did not answer tiles.
    @Test("a fixed-size standard window floats ahead of a rule")
    func fixedSizeBeforeRule() {
        var asked = false
        #expect(
            FloatDetection.autoFloatReason(
                structural: nil,
                fixedSize: { true }
            ) {
                asked = true
                return true
            } == .fixedSize
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

    /// A window offering Cancel in place of close is a progress
    /// window (#2653): the fixed-size guess, whatever its zoom
    /// button says, and a Tile rule escapes it like any guess.
    @Test("Cancel in place of close floats on the fixed-size guess")
    func cancelInsteadOfClose() {
        func reason(
            _ subrole: String = kAXStandardWindowSubrole,
            cancels: Bool,
            rules: FloatRules = FloatRules()
        ) -> AutoFloatReason? {
            FloatDetection.autoFloatReason(
                WindowFacts(
                    role: kAXWindowRole,
                    subrole: subrole,
                    layer: 0,
                    zoomable: { true },
                    cancelsInsteadOfClosing: { cancels }
                ) { "Archive Utility" },
                bundleID: "com.apple.archiveutility",
                rules: rules
            )
        }
        #expect(reason(cancels: true) == .fixedSize)
        #expect(reason(cancels: false) == nil)
        #expect(reason(kAXDialogSubrole, cancels: true) == .panel)
        let tiled = FloatRules(
            [],
            guess: FloatGuess(tileRules: ["com.apple.archiveutility"])
        )
        #expect(reason(cancels: true, rules: tiled) == nil)
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
