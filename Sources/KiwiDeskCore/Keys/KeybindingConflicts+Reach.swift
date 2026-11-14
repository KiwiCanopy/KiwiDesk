import Foundation

/// Which keys still fire a row whose modifiers take either side,
/// beside rows of its chord that name a side (#3256), and whether a
/// higher consumer takes a sided row's one form (#3278). Read from
/// `KeyboardTapArming.rows(for:)`, asked in `KeyboardTapConsumer`'s
/// order as the tap asks it, each of the router that fires it, so
/// no reader restates which row wins. Residue: rows meet by
/// registered chord, so a keypad twin's narrowing goes unsaid, and
/// a Hyper row is Carbon's, which reads it either-side.
public struct SideReach: Equatable, Sendable {
    /// One way of holding the row's modifiers, sides named, and the
    /// row that a press held that way fires.
    public struct Taken: Equatable, Sendable {
        public let combo: KeyCombo
        public let by: KeyBinding
    }

    /// The side-named forms of the row that still fire it.
    public let answered: [KeyCombo]
    /// The forms another row takes; never empty.
    public let taken: [Taken]

    /// No key fires the row any more.
    public var isDead: Bool { answered.isEmpty }

    /// Each row taking a form, once, in the order it first takes one.
    public var takers: [KeyBinding] {
        var seen: Set<UUID> = []
        return taken.map(\.by).filter { seen.insert($0.id).inserted }
    }

    /// The one combo the answered forms spell, nil where they need
    /// more than one: `Right ⌘⌘` for a ⌘⌘ row beside `Left ⌘⌘`.
    public var runs: KeyCombo? { Self.spelled(answered) }

    /// The one row taking the rest and the one combo it takes, nil
    /// where several rows take forms or they need more than one combo.
    public var takenBy: Taken? {
        guard let by = taken.first?.by,
            taken.allSatisfy({ $0.by.id == by.id }),
            let combo = Self.spelled(taken.map(\.combo))
        else { return nil }
        return Taken(combo: combo, by: by)
    }

    /// The single combo whose side-named forms are exactly `forms`:
    /// a modifier held on both sides across them stays either-side.
    static func spelled(_ forms: [KeyCombo]) -> KeyCombo? {
        guard let first = forms.first else { return nil }
        var modifiers = first.modifiers
        var choices = 1
        for kind in ModifierKind.allCases {
            let sides = Set(forms.compactMap { $0.modifiers.side(of: kind) })
            guard sides.count == 2 else { continue }
            for side in ModifierSide.allCases {
                modifiers.remove(.side(side, of: kind))
            }
            choices *= 2
        }
        guard choices == Set(forms).count else { return nil }
        return KeyCombo(keyCode: first.keyCode, modifiers: modifiers)
    }
}

extension KeybindingConflicts {
    /// The reach of `binding` within its layer, nil where no other
    /// row narrows it: a row naming every side it has that still
    /// fires, a chord while sides are not told apart (`Carbon`
    /// reads it either-side), or no rival on its chord.
    public static func sideReach(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        distinguishingSides: Bool
    ) -> SideReach? {
        guard let parsed = KeyCombo.parse(binding.combo) else {
            return nil
        }
        let rivals = bindings.compactMap { other in
            KeyCombo.parse(other.combo).flatMap {
                $0.registered == parsed.registered ? (other, $0) : nil
            }
        }
        return sideReach(
            for: binding,
            parsed: parsed,
            among: rivals,
            distinguishingSides: distinguishingSides
        )
    }

    /// The reach over rows already parsed and grouped by chord.
    static func sideReach(
        for binding: KeyBinding,
        parsed: KeyCombo,
        among rivals: some Sequence<(KeyBinding, KeyCombo)>,
        distinguishingSides: Bool
    ) -> SideReach? {
        guard parsed.isTap || distinguishingSides else { return nil }
        let open = ModifierKind.allCases.filter {
            parsed.modifiers.contains($0.plain)
                && parsed.modifiers.side(of: $0) == nil
        }
        let rivals = Array(rivals)
        let arming = tapArming(
            over: rivals,
            distinguishingSides: distinguishingSides
        )
        let consumers = KeyboardTapConsumer.allCases.map {
            arming.rows(for: $0).map { ($0.0, $0.1.binding) }
        }
        guard consumers.joined().contains(where: { $0.1.id == binding.id })
        else { return nil }
        var answered: [KeyCombo] = []
        var taken: [SideReach.Taken] = []
        for form in forms(of: parsed, opening: open) {
            guard let winner = winner(form, asking: consumers) else {
                continue
            }
            if winner.id == binding.id {
                answered.append(form)
            } else {
                taken.append(.init(combo: form, by: winner))
            }
        }
        return taken.isEmpty
            ? nil : SideReach(answered: answered, taken: taken)
    }

    /// Every side-named form of `combo`, one per way of holding the
    /// `open` modifiers; a fully sided combo is its own one form.
    private static func forms(
        of combo: KeyCombo,
        opening open: [ModifierKind]
    ) -> [KeyCombo] {
        open.reduce([combo]) { partial, kind in
            partial.flatMap { form in
                ModifierSide.allCases.map { side in
                    var modifiers = form.modifiers
                    modifiers.insert(.side(side, of: kind))
                    return KeyCombo(
                        keyCode: form.keyCode,
                        modifiers: modifiers
                    )
                }
            }
        }
    }

    /// The row a press held as `form` fires: the first consumer
    /// with a row answering it decides, as the keyboard tap does.
    private static func winner(
        _ form: KeyCombo,
        asking consumers: [[(KeyCombo, KeyBinding)]]
    ) -> KeyBinding? {
        for rows in consumers {
            if let index = winner(form, rows: rows.map(\.0)) {
                return rows[index].1
            }
        }
        return nil
    }

    /// The index among `rows` of the row a press held as `form`
    /// fires, asked of the router that fires it.
    private static func winner(_ form: KeyCombo, rows: [KeyCombo]) -> Int? {
        if let count = form.tapCount, let kind = form.tapKind,
            let side = form.modifiers.side(of: kind)
        {
            let tapRows = rows.enumerated().map {
                ModifierTapRow(combo: $0.element, id: UInt32($0.offset))
            }
            let tap = ModifierTap(ModifierKey(kind, side), count: count)
            return ModifierTapRouter.match(tapRows, tap).map { Int($0.id) }
        }
        let sideRows = rows.enumerated().map {
            SideTapRow(
                keyCode: $0.element.keyCode,
                modifiers: $0.element.modifiers,
                id: UInt32($0.offset)
            )
        }
        return SideTapRow.match(
            sideRows,
            keyCode: form.keyCode,
            held: form.modifiers
        ).map { Int($0.id) }
    }
}

extension KeyboardTapArming.Armed
where Row == KeyBinding, Leader == KeyBinding {
    var binding: KeyBinding {
        switch self {
        case .row(let binding), .leader(_, let binding): binding
        }
    }
}
