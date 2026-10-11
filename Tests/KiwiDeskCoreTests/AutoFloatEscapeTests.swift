import AppKit
import Testing

@testable import KiwiDeskCore

/// The escape for automatic floats (#2173): a guess — a fixed
/// size, no Dock icon — floats a window only while
/// `float_automatically` is on and its app has no Tile rule.
/// Structure and a Float rule float it either way.
@Suite("Automatic float escape (#2173)")
struct AutoFloatEscapeTests {
    private static let app = "com.valvesoftware.steam"

    private func facts(
        _ subrole: String = kAXStandardWindowSubrole,
        zoomable: Bool? = false
    ) -> WindowFacts {
        WindowFacts(
            role: kAXWindowRole,
            subrole: subrole,
            layer: 0,
            zoomable: { zoomable }
        ) { "Friends" }
    }

    private func reason(
        _ facts: WindowFacts,
        _ rules: FloatRules
    ) -> AutoFloatReason? {
        FloatDetection.autoFloatReason(
            facts,
            bundleID: Self.app,
            rules: rules
        )
    }

    @Test("a guess floats only where it applies")
    func guessApplies() {
        let on = FloatGuess()
        #expect(on.applies(to: Self.app))
        #expect(on.applies(to: nil))
        let tiled = FloatGuess(tileRules: ["COM.valvesoftware.Steam"])
        #expect(!tiled.applies(to: Self.app))
        #expect(tiled.applies(to: "com.apple.mail"))
        #expect(!FloatGuess(enabled: false).applies(to: "com.apple.mail"))
        #expect(tiled.tileRules == [Self.app])
    }

    @Test("a fixed size floats on the guess, and tiles without it")
    func fixedSizeIsAGuess() {
        #expect(reason(facts(), FloatRules()) == .fixedSize)
        let tiled = FloatRules(guess: FloatGuess(tileRules: [Self.app]))
        #expect(reason(facts(), tiled) == nil)
        let off = FloatRules(guess: FloatGuess(enabled: false))
        #expect(reason(facts(), off) == nil)
    }

    /// The ruled precedence: structure, then a Float rule, then a
    /// Tile rule, then the guess.
    @Test("structure and a Float rule float past a Tile rule")
    func structureAndRuleWin() {
        let tiled = FloatGuess(tileRules: [Self.app])
        #expect(
            reason(facts(kAXDialogSubrole), FloatRules(guess: tiled))
                == .panel
        )
        let ruled = FloatRules(["\(Self.app):Friends"], guess: tiled)
        #expect(reason(facts(), ruled) == .rule)
        let off = FloatRules(
            ["\(Self.app):Friends"],
            guess: FloatGuess(enabled: false)
        )
        #expect(reason(facts(), off) == .rule)
    }

    /// No Dock icon is a guess too: with a Tile rule the app's
    /// windows go through detection like any other app's.
    @Test("a Dock-less app's windows tile under a Tile rule")
    func accessoryAppIsAGuess() {
        func verdict(_ facts: WindowFacts, _ rules: FloatRules)
            -> FloatVerdict
        {
            EventLoop.composeVerdict(
                .facts(facts),
                pid: 1,
                activationPolicy: .accessory,
                tilesAsOwnWindow: false,
                bundleID: Self.app,
                rules: rules
            )
        }
        let resizable = facts(zoomable: true)
        #expect(verdict(resizable, FloatRules()) == .floats(.accessoryApp))
        let tiled = FloatRules(guess: FloatGuess(tileRules: [Self.app]))
        #expect(verdict(resizable, tiled) == .tiles)
        #expect(
            verdict(facts(kAXDialogSubrole), tiled) == .floats(.panel)
        )
        let off = FloatRules(guess: FloatGuess(enabled: false))
        #expect(verdict(resizable, off) == .tiles)
        #expect(verdict(facts(), off) == .tiles)
    }

    /// Own chrome is structure, never a guess.
    @MainActor
    @Test("own chrome floats with the guess off")
    func ownChromeIsNotAGuess() {
        let verdict = EventLoop.composeVerdict(
            .facts(facts(zoomable: true)),
            pid: getpid(),
            activationPolicy: .accessory,
            tilesAsOwnWindow: false,
            bundleID: Self.app,
            rules: FloatRules(guess: FloatGuess(enabled: false))
        )
        #expect(verdict == .floats(.panel))
    }

    @Test("a guess's refusal names App Rules; structure says always")
    func refusalWording() {
        #expect(AutoFloatReason.fixedSize.failure.contains("automatically"))
        #expect(
            AutoFloatReason.accessoryApp.failure.contains("automatically")
        )
        #expect(AutoFloatReason.panel.failure.contains("always"))
    }
}
