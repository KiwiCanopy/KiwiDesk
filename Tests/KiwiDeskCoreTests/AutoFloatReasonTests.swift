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
