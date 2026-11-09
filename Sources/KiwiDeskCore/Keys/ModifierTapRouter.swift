import Foundation

/// One modifier-tap binding the keyboard tap answers (#1872).
struct ModifierTapRow: Hashable, Sendable {
    /// A tap combo (`KeyCombo.isTap`).
    var combo: KeyCombo
    var id: UInt32
    /// Bound to a KiwiHub side, so it fires while KiwiHub is key
    /// (`ModifierTapHold`, #1229).
    var opensKiwiHubSide = false
}

/// The `.modifierTaps` consumer's decision (#1872): the one
/// detector fed every event, its taps matched to rows. Pure, so a
/// test drives it with fabricated events; the tap holds it under
/// a lock on its own thread.
struct ModifierTapRouter: Sendable {
    private(set) var rows: [ModifierTapRow] = []
    private var detector = ModifierTapDetector()

    /// The rows to answer. A key no double-tap row listens on
    /// fires its single tap at the release, with no wait.
    mutating func setRows(_ rows: [ModifierTapRow]) {
        self.rows = rows
        detector.immediate = Self.immediateKeys(rows)
    }

    /// The ids `input` fires, and the token a single tap waits on.
    mutating func feed(
        _ input: ModifierTapDetector.Input
    ) -> (ids: [UInt32], pending: UInt64?) {
        let out = detector.feed(input)
        let ids = out.taps.compactMap { Self.match(rows, $0)?.id }
        return (ids, out.pending?.token)
    }

    /// The id the single tap behind `token` fires, if any.
    mutating func expire(_ token: UInt64) -> UInt32? {
        detector.expire(token).flatMap { Self.match(rows, $0)?.id }
    }

    /// The row `tap` fires: among those answering it, the one
    /// naming a side, so `rcmd+rcmd` wins over `cmd+cmd` on the
    /// right key and the either-side row keeps the left.
    static func match(
        _ rows: [ModifierTapRow],
        _ tap: ModifierTap
    ) -> ModifierTapRow? {
        guard let pressed = tap.combo else { return nil }
        return rows.filter {
            $0.combo.tapCount == tap.count
                && $0.combo.modifiers.answers(pressed.modifiers)
        }
        .max { lhs, rhs in
            (lhs.combo.modifiers.isSided ? 1 : 0, lhs.id)
                < (rhs.combo.modifiers.isSided ? 1 : 0, rhs.id)
        }
    }

    /// Every physical key no double-tap row answers.
    static func immediateKeys(_ rows: [ModifierTapRow]) -> Set<ModifierKey> {
        var keys: Set<ModifierKey> = []
        for kind in ModifierKind.allCases {
            for side in ModifierSide.allCases {
                let key = ModifierKey(kind, side)
                let double = ModifierTap(key, count: 2)
                if match(rows, double) == nil { keys.insert(key) }
            }
        }
        return keys
    }
}
