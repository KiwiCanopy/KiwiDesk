import Foundation

/// Where each row of a layer goes when the layer is armed (#3278):
/// the one home of which rows the keyboard tap's consumers answer.
/// `KeybindingManager.activate` arms from it, and the conflict
/// readers (`KeybindingConflicts.sideReach`, `pressPath`) ask the
/// same rows through the one `KeybindingConflicts.tapArming`, so
/// none can disagree. Pure: `Row` is
/// whatever names a press row (a Lua ref, a Settings binding) and
/// `Leader` whatever names a sequence.
struct KeyboardTapArming<Row, Leader> {
    /// What a consumer answers with: a press row, or a leader with
    /// its sequence's index, which `KeyboardTap.leaderID(_:)` names.
    enum Armed {
        case row(Row)
        case leader(index: Int, Leader)
    }

    /// Press rows on a leader's exact chord: the sequence takes the
    /// chord, so the row is never armed (#1871).
    private(set) var heldByLeader: [(KeyCombo, Row)] = []
    /// Modifier taps, the `.modifierTaps` consumer's (#1872).
    private(set) var taps: [(KeyCombo, Row)] = []
    /// Hyper rows, registered only while the Hyper key is held.
    private(set) var hyper: [(KeyCombo, Row)] = []
    /// The chords `.sides` answers (#2601).
    private(set) var sides: [(KeyCombo, Row)] = []
    /// Every other row: a Carbon hotkey.
    private(set) var carbon: [(KeyCombo, Row)] = []
    /// Every leader, in sequence order.
    let leaders: [(KeyCombo, Leader)]

    /// Sorts `rows`, in their order, beside `leaders`.
    init(
        rows: [(KeyCombo, Row)],
        leaders: [(KeyCombo, Leader)],
        distinguishingSides: Bool
    ) {
        self.leaders = leaders
        let held = Set(leaders.map(\.0))
        let tapped = Self.tappedChords(
            rows.map(\.0) + leaders.map(\.0),
            distinguishingSides: distinguishingSides
        )
        for row in rows {
            let combo = row.0
            if held.contains(combo) {
                heldByLeader.append(row)
            } else if combo.isTap {
                taps.append(row)
            } else if combo.modifiers.contains(.hyper) {
                hyper.append(row)
            } else if tapped.contains(combo.unsided) {
                sides.append(row)
            } else {
                carbon.append(row)
            }
        }
    }

    /// No rows: what a suspended manager arms.
    static var empty: Self {
        Self(rows: [], leaders: [], distinguishingSides: false)
    }

    /// The rows `consumer` is armed with, in the order the tap
    /// hands them to it: `.sequences` the chord leaders, `.sides`
    /// the side rows, `.modifierTaps` the taps, then the tap leaders.
    func rows(for consumer: KeyboardTapConsumer) -> [(KeyCombo, Armed)] {
        let leading = leaders.enumerated().map {
            ($0.element.0, Armed.leader(index: $0.offset, $0.element.1))
        }
        switch consumer {
        case .sequences:
            return leading.filter { !$0.0.isTap }
        case .sides:
            return sides.map { ($0.0, .row($0.1)) }
        case .modifierTaps:
            return taps.map { ($0.0, .row($0.1)) }
                + leading.filter(\.0.isTap)
        }
    }

    /// The either-side chords `.sides` answers: those a sided row or
    /// a sided chord leader names, while sides are told apart, so
    /// the either-side row on such a chord moves with it and its
    /// press on the other side never races Carbon.
    private static func tappedChords(
        _ combos: [KeyCombo],
        distinguishingSides: Bool
    ) -> Set<KeyCombo> {
        guard distinguishingSides else { return [] }
        return Set(
            combos.filter {
                $0.modifiers.isSided && !$0.modifiers.contains(.hyper)
            }
            .map(\.unsided)
        )
    }
}
