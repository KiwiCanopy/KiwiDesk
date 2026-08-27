import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The #1055 Lane B generalization: a CORROBORATED bound
/// answers asks beyond it at the consume site, revocably —
/// per-ask entries keep precedence, a single entry never
/// generalizes, and the fixed-span lend corroborates the one
/// direction the other has already proven. The probe evidence
/// and the owner ruling are on the issue; the amended #677
/// rule is `EffectiveSizeBound`'s header.
@Suite("Size bound generalization (#1055 Lane B)")
struct SizeBoundGeneralizationTests {
    /// Two distinct asks agreeing at 715 — the corroborated
    /// ceiling every positive case builds on.
    private let ceiling = EffectiveSizeBound(
        width: [
            .init(asked: 800, answered: 715),
            .init(asked: 900, answered: 715),
        ]
    )

    @Test("A corroborated ceiling answers asks above it")
    func ceilingAnswersAbove() {
        #expect(ceiling.consumedWidth(asking: 1200) == 715)
        // Every ask above the ceiling is answered — the entry
        // asks are not special once the bound is corroborated.
        #expect(ceiling.consumedWidth(asking: 750) == 715)
        // An ask BELOW the ceiling is unlearned range — it
        // must be probed, not silently swapped (#677's rule,
        // kept): the app may accept it.
        #expect(ceiling.consumedWidth(asking: 600) == nil)
        // At the ceiling itself (within tolerance) nothing
        // consumes either — the app complies there.
        #expect(ceiling.consumedWidth(asking: 715) == nil)
        // The unlearned axis never generalizes.
        #expect(ceiling.consumedHeight(asking: 1200) == nil)
    }

    @Test("A per-ask entry outranks the generalization")
    func perAskPrecedence() {
        // The falsifier the ruling requires: an app that
        // contradicts the bound at a generalized ask (the
        // aspect-coupled emulator after an other-axis change)
        // produces an ordinary same-ask entry, and that entry
        // answers first.
        let contradicted = EffectiveSizeBound(
            width: [
                .init(asked: 800, answered: 715),
                .init(asked: 900, answered: 715),
                .init(asked: 1000, answered: 650),
            ]
        )
        #expect(
            contradicted.consumedWidth(asking: 1000) == 650
        )
        // Other generalized asks keep the corroborated answer.
        #expect(
            contradicted.consumedWidth(asking: 1200) == 715
        )
    }

    @Test("A single entry never generalizes")
    func singleEntryNeverGeneralizes() {
        let single = EffectiveSizeBound(
            width: .init(asked: 900, answered: 715)
        )
        #expect(single.consumedWidth(asking: 1200) == nil)
        #expect(single.consumedWidth(asking: 500) == nil)
    }

    @Test("A corroborated floor answers asks below it")
    func floorAnswersBelow() {
        let floor = EffectiveSizeBound(
            width: [
                .init(asked: 300, answered: 480),
                .init(asked: 240, answered: 480),
            ]
        )
        #expect(floor.consumedWidth(asking: 100) == 480)
        #expect(floor.consumedWidth(asking: 490) == nil)
    }

    @Test("The fixed-span lend corroborates the other side")
    func fixedSpanLend() {
        // System Settings' signature: the app answers 825 from
        // BOTH directions. The corroborated ceiling lends its
        // confidence to the single floor entry at the same
        // span — which is what lets the shrink cue arm on the
        // first press below the span instead of after a second
        // silent walk (#1055 repro C).
        let fixed = EffectiveSizeBound(
            width: [
                .init(asked: 900, answered: 825),
                .init(asked: 1000, answered: 825),
                .init(asked: 800, answered: 825),
            ]
        )
        #expect(fixed.maxWidth == 825)
        #expect(fixed.minWidth == 825)

        // The mirror: a corroborated floor lends the single
        // ceiling entry.
        let mirrored = EffectiveSizeBound(
            width: [
                .init(asked: 700, answered: 825),
                .init(asked: 750, answered: 825),
                .init(asked: 900, answered: 825),
            ]
        )
        #expect(mirrored.minWidth == 825)
        #expect(mirrored.maxWidth == 825)
    }

    @Test("Two single entries cannot bootstrap each other")
    func lendNeverBootstraps() {
        // The lend consults only the PAIRED value of the other
        // direction: one entry per side agreeing on a span is
        // still two uncorroborated observations.
        let twoSingles = EffectiveSizeBound(
            width: [
                .init(asked: 900, answered: 825),
                .init(asked: 800, answered: 825),
            ]
        )
        #expect(twoSingles.maxWidth == nil)
        #expect(twoSingles.minWidth == nil)
    }

    @Test("Snap-grid data never lends")
    func snapDataNeverLends() {
        // Terminal-shaped answers track the ask on both sides,
        // so nothing pairs and nothing lends.
        let snap = EffectiveSizeBound(
            width: [
                .init(asked: 800, answered: 797),
                .init(asked: 900, answered: 898),
                .init(asked: 500, answered: 503),
            ]
        )
        #expect(snap.maxWidth == nil)
        #expect(snap.minWidth == nil)
        #expect(snap.consumedWidth(asking: 1200) == nil)
    }

    @Test("Explains covers a generalized target at the bound")
    func explainsGeneralizedTarget() {
        // The retile skip's half of the churn fix: a target
        // above the corroborated ceiling with the window
        // resting AT the ceiling is answered, not re-issued.
        #expect(
            ceiling.explains(
                currentSize: CGSize(width: 715, height: 600),
                targetSize: CGSize(width: 1200, height: 600)
            )
        )
        // A window OFF the bound is a strand, exactly as for a
        // per-ask entry — the engine must issue the target.
        #expect(
            !ceiling.explains(
                currentSize: CGSize(width: 650, height: 600),
                targetSize: CGSize(width: 1200, height: 600)
            )
        )
    }

    @Test("The centered residue rides the generalization")
    func centeredResidueGeneralizes() {
        // Monocle's park and the lone scrolling window take
        // `centered(in:)`, which consumes — a slot above the
        // corroborated ceiling centers the answered span
        // instead of probing every new slot size.
        let slot = CGRect(x: 0, y: 0, width: 1201, height: 600)
        let frame = ceiling.centered(in: slot)
        #expect(frame?.width == 715)
        #expect(frame?.midX == slot.midX)
    }
}
