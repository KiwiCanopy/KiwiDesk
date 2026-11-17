import Testing

@testable import KiwiDeskCore

/// A click closes an open key sequence, save the screenshot's own
/// (#3412): ⌘⇧4 and its clipboard twin keep the sequence open
/// through one click, ⌘⇧5 through its clicks until a key-down, and
/// each within `KeySequenceRouter.captureLimit`. The other shortcuts
/// that leave the panel up take no click, so a click still closes.
@Suite("Key sequence screenshot capture")
struct KeySequenceCaptureTests {
    typealias Router = KeySequenceRouterTests

    private func router() -> KeySequenceRouter {
        var router = KeySequenceRouter()
        router.setSequences(
            [Router.sequence],
            passing: .live(reading: { _ in nil })
        )
        return router
    }

    private func press(
        _ router: inout KeySequenceRouter,
        _ text: String,
        at now: Double = 0
    ) -> KeySequenceRouter.Outcome {
        let combo = KeyCombo.parse(text)!
        return router.press(
            keyCode: combo.keyCode,
            held: combo.modifiers,
            isRepeat: false,
            now: now
        )
    }

    /// The router after the leader and `chord`, both at time 0.
    private func passed(_ chord: String) -> KeySequenceRouter {
        var router = router()
        _ = press(&router, "ctrl+alt+space")
        #expect(press(&router, chord) == .passed(closing: false))
        return router
    }

    @Test("a click closes an open sequence")
    func clickCloses() {
        var router = router()
        #expect(router.mouseDown(at: 0) == .pass)
        _ = press(&router, "ctrl+alt+space")
        #expect(router.mouseDown(at: 0) == .closed)
        #expect(!router.isOpen)
    }

    @Test("a selection screenshot's one click keeps it open")
    func selectionSpendsOneClick() {
        for chord in ["cmd+shift+4", "ctrl+cmd+shift+4"] {
            var router = passed(chord)
            #expect(router.isCapturing, "\(chord)")
            #expect(router.mouseDown(at: 1) == .pass, "\(chord)")
            #expect(router.isOpen, "\(chord)")
            #expect(!router.isCapturing, "\(chord)")
            #expect(router.mouseDown(at: 2) == .closed, "\(chord)")
        }
    }

    @Test("the screenshot toolbar keeps it open through its clicks")
    func toolsKeepClicks() {
        var router = passed("cmd+shift+5")
        for time in [1.0, 2, 3] {
            #expect(router.mouseDown(at: time) == .pass)
        }
        #expect(router.isOpen)
        #expect(router.isCapturing)
    }

    @Test("a key-down ends the capture")
    func keyDownEnds() {
        var router = passed("cmd+shift+5")
        #expect(press(&router, "q", at: 1) == .unbound)
        #expect(!router.isCapturing)
        #expect(router.mouseDown(at: 2) == .closed)
    }

    @Test("the capture ends at its bound")
    func boundEnds() {
        let limit = KeySequenceRouter.captureLimit
        var router = passed("cmd+shift+5")
        #expect(router.mouseDown(at: limit.nextDown) == .pass)
        #expect(router.mouseDown(at: limit) == .closed)
    }

    @Test("a shortcut that takes no click opens no capture")
    func noClickNoCapture() {
        for chord in ["cmd+shift+3", "ctrl+cmd+shift+3"] {
            var router = passed(chord)
            #expect(!router.isCapturing, "\(chord)")
            #expect(router.mouseDown(at: 1) == .closed, "\(chord)")
        }
    }

    @Test("a close drops the capture")
    func closeDrops() {
        var router = passed("cmd+shift+5")
        router.close()
        #expect(!router.isCapturing)
        _ = press(&router, "ctrl+alt+space", at: 1)
        #expect(router.mouseDown(at: 2) == .closed)
    }

    @Test("only the pointer screenshots capture")
    func tiers() {
        let capturing = SystemShortcut.allCases.filter {
            [.capturesClick, .capturesClicks].contains($0.sequenceTier)
        }
        #expect(
            Set(capturing) == [
                .screenshotSelection, .screenshotSelectionToClipboard,
                .screenshotTools,
            ]
        )
        #expect(SystemShortcut.screenshotTools.sequenceTier == .capturesClicks)
    }
}
