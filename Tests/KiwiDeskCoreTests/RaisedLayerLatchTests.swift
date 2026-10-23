import ApplicationServices
import Testing

@testable import KiwiDeskCore

/// A raised layer is judged at adoption (#2572): Chromium lifts
/// its tiled main window to layer 999 while a permission prompt is
/// up, and a recheck floated it on each lift. A window adopted on
/// a raised layer keeps floating through its rechecks, and a
/// subrole that floats still floats a tiled window.
@Suite("Raised-layer latch (#2572)")
@MainActor
struct RaisedLayerLatchTests {
    private let id = WindowID(43)
    private let pid: pid_t = 900_043

    private func facts(_ subrole: String, layer: Int) -> WindowFacts {
        WindowFacts(
            role: kAXWindowRole,
            subrole: subrole,
            layer: layer,
            zoomable: { true }
        ) { "Brave" }
    }

    private func reason(_ facts: WindowFacts) -> AutoFloatReason? {
        FloatDetection.autoFloatReason(
            facts,
            bundleID: "com.brave.Browser",
            rules: FloatRules()
        )
    }

    private func recheck(
        _ core: KiwiCore,
        _ reason: AutoFloatReason?
    ) -> [KiwiEvent] {
        var events: [KiwiEvent] = []
        // Only the float flag is the subject here.
        core.eventLoop.detectedFullscreen[id] = false
        core.eventLoop.onEvent = { events.append($0) }
        core.eventLoop.recheckFloat(
            id: id,
            pid: pid,
            app: AppRef(pid: pid),
            reading: TrackedReading(
                fullscreen: false,
                subrole: "",
                frame: .zero,
                autoReason: reason,
                traits: nil
            )
        )
        return events
    }

    @Test("the layer alone is a raised layer; a subrole is a panel")
    func reasonNamesTheCause() {
        let standard = kAXStandardWindowSubrole
        #expect(reason(facts(standard, layer: 999)) == .raisedLayer)
        #expect(reason(facts(standard, layer: 3)) == .raisedLayer)
        #expect(reason(facts(standard, layer: 0)) == nil)
        #expect(reason(facts(kAXDialogSubrole, layer: 999)) == .panel)
        #expect(reason(facts(kAXDialogSubrole, layer: 0)) == .panel)
    }

    @Test("a raised layer is structure: an overlay, not a guess")
    func raisedLayerIsStructure() {
        #expect(!AutoFloatReason.raisedLayer.isGuess)
        #expect(
            EventLoop.isOverlay(
                .floats(.raisedLayer),
                ownProcess: false,
                structural: false
            )
        )
        #expect(AutoFloatReason.raisedLayer.escapes.isEmpty)
    }

    /// The device sequence: each lift to 999 and back while the
    /// prompt is up, then Allow.
    @Test("a recheck never floats a tiled window on its layer")
    func tiledStaysTiled() {
        let core = makeTestCore()
        core.eventLoop.detectedFloating[id] = .tiles
        var events: [KiwiEvent] = []
        for read: AutoFloatReason? in [.raisedLayer, nil, .raisedLayer] {
            events += recheck(core, read)
            #expect(core.eventLoop.detectedFloating[id] == .tiles)
        }
        #expect(events.isEmpty)
    }

    @Test("a window adopted on a raised layer keeps floating")
    func adoptedStays() {
        let core = makeTestCore()
        core.eventLoop.detectedFloating[id] = .floats(.raisedLayer)
        let events = recheck(core, .raisedLayer)
        #expect(
            core.eventLoop.detectedFloating[id] == .floats(.raisedLayer)
        )
        #expect(events.isEmpty)
    }

    /// A misread subrole at adoption (Ghostty's quick terminal,
    /// layer 3) floats as a panel and must not tile when it later
    /// reads standard on the same raised layer.
    @Test("a floating panel stays floating when only the layer holds")
    func panelKeepsFloating() {
        let core = makeTestCore()
        core.eventLoop.detectedFloating[id] = .floats(.panel)
        _ = recheck(core, .raisedLayer)
        #expect(core.eventLoop.detectedFloating[id]?.floats == true)
    }

    @Test("a subrole that floats still floats a tiled window")
    func panelStillFloats() {
        let core = makeTestCore()
        core.eventLoop.detectedFloating[id] = .tiles
        _ = recheck(core, .panel)
        #expect(core.eventLoop.detectedFloating[id] == .floats(.panel))
    }
}
