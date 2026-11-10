import Foundation

/// One chord the side tap answers: a key and the modifiers it is
/// pressed with, sides included, and the binding it fires (#2601).
struct SideTapRow: Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: HotkeyModifiers
    var id: UInt32

    /// The row a press of `keyCode` holding `held` fires: among
    /// the rows it answers, the one naming the most sides, so a
    /// sided chord wins on its side and an either-side one on the
    /// other.
    static func match(
        _ rows: [SideTapRow],
        keyCode: UInt32,
        held: HotkeyModifiers
    ) -> SideTapRow? {
        rows.filter {
            $0.keyCode == keyCode && $0.modifiers.answers(held)
        }
        .max { lhs, rhs in
            let left = lhs.modifiers.intersection(.sides).rawValue
            let right = rhs.modifiers.intersection(.sides).rawValue
            // A tie breaks on the bits, never the rows' order.
            return (left.nonzeroBitCount, left)
                < (right.nonzeroBitCount, right)
        }
    }
}

/// The rows every consumer answers, handed to the tap through one
/// door, so no consumer's rows can be left behind a suspend.
struct KeyboardTapRows: Equatable, Sendable {
    var sides: [SideTapRow] = []
    var taps: [ModifierTapRow] = []
    /// The current layer's key sequences (#1871); a tap leader also
    /// rides `taps`, under `KeyboardTap.leaderID(_:)`.
    var sequences: [KeySequence] = []
    /// The macOS shortcuts an open sequence lets through (#3173),
    /// handed to the router with the sequences.
    var sequencePassing = SequencePassChords.none
    /// The epoch every sequence decision made over these rows
    /// carries.
    var sequenceGeneration: UInt64 = 0

    static let empty = KeyboardTapRows()

    /// The consumers these rows make live: one per non-empty field.
    var consumers: Set<KeyboardTapConsumer> {
        Set(
            KeyboardTapConsumer.allCases.filter {
                switch $0 {
                case .sequences: !sequences.isEmpty
                case .sides: !sides.isEmpty
                case .modifierTaps: !taps.isEmpty
                }
            }
        )
    }
}
