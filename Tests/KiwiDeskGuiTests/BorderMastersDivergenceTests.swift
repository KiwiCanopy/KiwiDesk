import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the shared masters SHOW when the strokes they write
/// disagree (#754). Lua can move any one stroke on its own, so
/// "these two rows decide all three" is a claim the stored
/// config can falsify at any moment — and the corner row sits
/// directly above a ring preview drawing the answer it would
/// otherwise be hiding.
///
/// Two different answers, because the two controls can carry
/// different amounts of nothing: a segmented picker can show no
/// segment selected, a slider has no blank thumb. So the corner
/// master goes nil and the width master keeps showing the
/// ring's value; both raise the `?`. The write half is
/// `BorderMastersFanOutTests`.
@MainActor
@Suite("Border masters under divergence")
struct BorderMastersDivergenceTests {
    private func model() -> SettingsModel {
        makeTestModel()
    }

    private func gates(
        _ model: SettingsModel
    ) -> GapsBordersGates {
        GapsBordersGates(settings: model.config.settings)
    }

    /// Both halves agreeing is what puts a segment under the
    /// pill — including at a radius the GUI never wrote, since
    /// the drag pair really does draw rounded corners at 7 pt.
    @Test("agreeing halves select their segment")
    func agreementSelects() {
        let model = model()
        model.config.settings.dragCornerRadius = 7
        model.config.settings.borderStyle.cornerStyle = .rounded
        #expect(model.borderCornersMaster.wrappedValue == .rounded)
        model.config.settings.dragCornerRadius = 0
        model.config.settings.borderStyle.cornerStyle = .square
        #expect(model.borderCornersMaster.wrappedValue == .square)
    }

    /// The defect this suite exists for: `border.set_corner_\
    /// style("square")` against the shipped 16 pt radius used to
    /// show **Rounded** above a ring drawing square, and the
    /// inverse showed Square above a rounded preview. Neither
    /// half is wrong to trust, so the picker asserts neither.
    @Test("disagreeing halves select nothing")
    func disagreementSelectsNothing() {
        let model = model()
        model.config.settings.borderStyle.cornerStyle = .square
        model.config.settings.dragCornerRadius = 16
        #expect(model.borderCornersMaster.wrappedValue == nil)
        model.config.settings.borderStyle.cornerStyle = .rounded
        model.config.settings.dragCornerRadius = 0
        #expect(model.borderCornersMaster.wrappedValue == nil)
    }

    /// And a tap on either segment ends it — a picker showing
    /// nothing has to be recoverable from, or the blank state
    /// is a dead end rather than an honest one.
    @Test("either segment converges both halves")
    func anyPickConverges() {
        for style in [
            BorderStyle.CornerStyle.rounded, .square,
        ] {
            let model = model()
            model.config.settings.borderStyle.cornerStyle =
                .square
            model.config.settings.dragCornerRadius = 16
            model.borderCornersMaster.wrappedValue = style
            #expect(
                model.borderCornersMaster.wrappedValue == style
            )
        }
    }

    /// Re-affirming the segment already shown changes NOTHING
    /// stored. A stray tap is likelier than a deliberate one,
    /// and normalising a Lua-set 7 pt radius to 16 on it would
    /// move a value nobody named — while the screen showed the
    /// same word before and after, and the header counted a
    /// change.
    @Test("re-picking the shown segment writes nothing")
    func rePickIsIdempotent() {
        let model = model()
        model.config.settings.dragCornerRadius = 7
        model.config.settings.borderStyle.cornerStyle = .rounded
        let before = model.config.settings
        model.borderCornersMaster.wrappedValue = .rounded
        #expect(model.config.settings == before)
        #expect(model.config.settings.dragCornerRadius == 7)
    }

    /// Rounded still has to MEAN something where there is no
    /// rounding to keep: a zero radius is the square shape, so
    /// picking Rounded there writes the system radius.
    @Test("Rounded from zero writes the system radius")
    func roundedFromZeroWrites() {
        let model = model()
        model.config.settings.dragCornerRadius = 0
        model.borderCornersMaster.wrappedValue = .rounded
        #expect(
            model.config.settings.dragCornerRadius
                == GeometryUtils.systemWindowCornerRadius
        )
    }

    /// READING a master never stores. A profile Lua gave a 7 pt
    /// radius and a square ring arrives disagreeing with
    /// itself, and it STAYS that way until the user picks —
    /// nothing re-derives it at load, because that would
    /// rewrite a saved profile the user never opened this card
    /// to change.
    @Test("reading the masters rewrites nothing")
    func readingDoesNotWrite() {
        let model = model()
        model.config.settings.dragCornerRadius = 7
        model.config.settings.borderStyle.cornerStyle = .square
        model.config.settings.dragGhost.borderWidth = 2
        let before = model.config.settings
        _ = model.borderCornersMaster.wrappedValue
        _ = model.borderWidthMaster.wrappedValue
        #expect(model.config.settings == before)
    }

    /// The `?` predicate, per row: each master acknowledges its
    /// OWN strokes. A width master raising the sentence because
    /// the corners disagree would point at the wrong control.
    @Test("each master's ? tracks its own strokes")
    func differPredicateIsPerRow() {
        let model = model()
        #expect(
            !gates(model)
                .strokesDiffer(for: .borders(.borderWidthMaster))
        )
        #expect(
            !gates(model)
                .strokesDiffer(for: .borders(.borderCornerMaster))
        )
        model.config.settings.dragGhost.borderWidth = 2
        #expect(
            gates(model)
                .strokesDiffer(for: .borders(.borderWidthMaster))
        )
        #expect(
            !gates(model)
                .strokesDiffer(for: .borders(.borderCornerMaster))
        )
        model.config.settings.dragGhost.borderWidth =
            model.config.settings.borderStyle.width
        model.config.settings.borderStyle.cornerStyle = .square
        #expect(
            !gates(model)
                .strokesDiffer(for: .borders(.borderWidthMaster))
        )
        #expect(
            gates(model)
                .strokesDiffer(for: .borders(.borderCornerMaster))
        )
    }

    /// The drop zone is the third stroke and is easy to forget:
    /// the ring and the ghost agreeing is not the strokes
    /// agreeing.
    @Test("the drop zone counts toward the width ?")
    func dropZoneCountsToward() {
        let model = model()
        model.config.settings.dragDropZone.borderWidth = 2
        #expect(
            gates(model)
                .strokesDiffer(for: .borders(.borderWidthMaster))
        )
    }

    /// A row that is not a master gets no sentence — the
    /// default arm must stay silent rather than answering for
    /// every key in the census.
    @Test("only the masters answer the ? predicate")
    func nonMastersNeverDiffer() {
        let model = model()
        model.config.settings.dragGhost.borderWidth = 2
        model.config.settings.borderStyle.cornerStyle = .square
        for key in SettingKey.allCases
        where !SettingKey.masterWrites.keys.contains(key) {
            #expect(!gates(model).strokesDiffer(for: key))
        }
    }
}
