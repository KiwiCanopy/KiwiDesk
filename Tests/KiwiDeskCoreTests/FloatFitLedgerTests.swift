import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The float fit's refusal memo (#1091) — #677's shape one
/// subsystem over. Without it, an app whose minimum size exceeds
/// the bar-carved region is re-asked to shrink on every retile,
/// forever, having already refused (code review, 2026-08-29).
@Suite("Float fit refusal memo (#1091)")
struct FloatFitLedgerTests {
    private let window = WindowID(1)
    private let asked = CGSize(width: 800, height: 600)
    private let seen = CGSize(width: 1000, height: 700)

    @Test("An unrecorded ask is never a repeat")
    func freshAskIsNotARepeat() {
        let ledger = FloatFitLedger()
        #expect(
            !ledger.repeatsRefusal(
                window,
                asked: asked,
                seen: seen
            )
        )
    }

    @Test("The same ask against the same size is a repeat")
    func identicalAskRepeats() {
        var ledger = FloatFitLedger()
        ledger.record(window, asked: asked, seen: seen)
        #expect(
            ledger.repeatsRefusal(
                window,
                asked: asked,
                seen: seen
            )
        )
    }

    @Test("Either half moving makes it a fresh question")
    func aChangeOnEitherSideAsksAgain() {
        // The reason this needs no explicit invalidation: the
        // user resizing the window, the app changing its mind,
        // or a bar edit changing the region each move one half
        // of the pair.
        var ledger = FloatFitLedger()
        ledger.record(window, asked: asked, seen: seen)
        #expect(
            !ledger.repeatsRefusal(
                window,
                asked: CGSize(width: 700, height: 600),
                seen: seen
            )
        )
        #expect(
            !ledger.repeatsRefusal(
                window,
                asked: asked,
                seen: CGSize(width: 900, height: 700)
            )
        )
    }

    @Test("The memo is per window, and forgettable")
    func perWindowAndForgettable() {
        var ledger = FloatFitLedger()
        ledger.record(window, asked: asked, seen: seen)
        #expect(
            !ledger.repeatsRefusal(
                WindowID(2),
                asked: asked,
                seen: seen
            )
        )
        ledger.forget(window)
        #expect(
            !ledger.repeatsRefusal(
                window,
                asked: asked,
                seen: seen
            )
        )
    }
}
