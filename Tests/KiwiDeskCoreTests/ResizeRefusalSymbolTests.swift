import AppKit
import Testing

@testable import KiwiDeskCore

/// The refusal pill's leading glyph (#1260).
///
/// It was a constant — a SHRINK arrow drawn on all seven
/// sentences, four of which mean the opposite — so the pill's
/// one non-verbal channel contradicted the words beside it, and
/// did so most loudly in the narrow band where the words have
/// already truncated away.
///
/// The rule it now carries: **an arrow means a resize stopped, a
/// non-arrow means there is no resize here.**
@Suite("Resize refusal symbol")
struct ResizeRefusalSymbolTests {
    private let window = WindowID(1)
    private let other = WindowID(2)

    /// The structural refusals — the parameter does not exist —
    /// are the ones that must NOT wear an arrow, whatever
    /// symbol is chosen for them.
    @Test("no resize here is never drawn as an arrow")
    func structuralRefusalsCarryNoArrow() {
        for refusal: ResizeRefusal in [
            .noAxisHere(window), .layoutHasNoResize(window),
        ] {
            #expect(!refusal.pillSymbol.contains("arrow"))
        }
    }

    /// …and a stopped resize is always an arrow, so the two
    /// classes cannot collapse into one look.
    @Test("a stopped resize is always an arrow")
    func boundedRefusalsCarryAnArrow() {
        for refusal: ResizeRefusal in [
            .ownMinimum(window), .ownMaximum(window),
            .neighborMinimum(anchor: other, focused: window),
        ] {
            #expect(refusal.pillSymbol.contains("arrow"))
        }
    }

    /// The two ends of one gesture are told apart, or the glyph
    /// says "a resize stopped" and nothing more.
    @Test("shrink and grow are mirrored, not shared")
    func minimumAndMaximumDiffer() {
        #expect(
            ResizeRefusal.ownMinimum(window).pillSymbol
                != ResizeRefusal.ownMaximum(window).pillSymbol
        )
        // A neighbour's floor is a MINIMUM binding, and the pair
        // routes a shrink through it — a direction-derived glyph
        // would draw a grow arrow on a shrink gesture.
        #expect(
            ResizeRefusal.neighborMinimum(
                anchor: other,
                focused: window
            ).pillSymbol
                == ResizeRefusal.ownMinimum(window).pillSymbol
        )
    }

    /// Every name resolves. The trap this catches is invisible
    /// on a modern host: a symbol introduced after the macOS 14
    /// deployment target renders nil THERE and leaves an empty
    /// gutter, with no error anywhere.
    @Test("every symbol resolves to an image")
    func everySymbolResolves() {
        for refusal: ResizeRefusal in [
            .ownMinimum(window), .ownMaximum(window),
            .neighborMinimum(anchor: other, focused: window),
            .noAxisHere(window), .layoutHasNoResize(window),
        ] {
            #expect(
                NSImage(
                    systemSymbolName: refusal.pillSymbol,
                    accessibilityDescription: nil
                ) != nil,
                Comment(rawValue: refusal.pillSymbol)
            )
        }
    }
}
