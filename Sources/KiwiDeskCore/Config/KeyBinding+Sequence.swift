import Foundation

/// A sequence's end key and the step keys that lead to it (#1871).
public struct SequenceEndKey: Equatable, Sendable {
    /// The leader's chord, then each step key down to `binding`'s
    /// own, as stored.
    public var path: [String]
    public var binding: KeyBinding
}

extension KeyBinding {
    /// Whether this binding is a sequence node (#1871): a leader,
    /// or a step key that opens more keys.
    public var isSequence: Bool { kind == .sequence }

    /// A sequence node on `combo`, named `label` (#1871).
    public static func sequence(
        combo: String,
        label: String = "",
        steps: [KeyBinding] = []
    ) -> KeyBinding {
        KeyBinding(
            combo: combo,
            kind: .sequence,
            label: label,
            steps: steps
        )
    }

    /// Every end key under this node, depth first in stored order;
    /// empty for a binding that is not a sequence.
    public var endKeys: [SequenceEndKey] {
        guard let steps else { return [] }
        return steps.flatMap { step -> [SequenceEndKey] in
            guard step.isSequence else {
                return [
                    SequenceEndKey(path: [combo, step.combo], binding: step)
                ]
            }
            return step.endKeys.map {
                SequenceEndKey(path: [combo] + $0.path, binding: $0.binding)
            }
        }
    }

    /// The same node with every end key passed through `transform`
    /// — kept where it answers a binding, dropped where it answers
    /// nil. A binding that is not a sequence is `transform`'s own.
    public func mappingEndKeys(
        _ transform: (KeyBinding) -> KeyBinding?
    ) -> KeyBinding? {
        guard let steps else { return transform(self) }
        var node = self
        node.steps = steps.compactMap { $0.mappingEndKeys(transform) }
        return node
    }
}

extension KeyBinding {
    /// Whether `combo` may be a step key under the leader `leader`
    /// (#1871): the router's own rule, `KeySequence.admitsStep`. A
    /// spelling that does not parse is the recorder's to flag.
    public static func admitsStepKey(_ combo: String, under leader: String)
        -> Bool
    {
        guard let key = KeyCombo.parse(combo) else { return true }
        guard let lead = KeyCombo.parse(leader) else {
            return !key.isTap && KeySequence.admitsLeader(key)
        }
        return KeySequence.admitsStep(key, under: lead)
    }

    /// Whether `combo` may lead a sequence (`KeySequence.admitsLeader`).
    public static func admitsLeader(_ combo: String) -> Bool {
        KeyCombo.parse(combo).map(KeySequence.admitsLeader) ?? true
    }

    /// What a write compares of a row: its chord, its action and
    /// what it says of itself — a sequence its name and whole tree
    /// (#1871).
    public var shortcutShape: String {
        // `meta` whole, so a field it gains is compared too (#2544).
        ([combo, lua, String(describing: meta)]
            + (isSequence ? ["\u{1E}" + label] : [])
            // Each child bracketed, so a key one step up never
            // reads as the same tree.
            + (steps ?? []).map { "\u{1D}" + $0.shortcutShape + "\u{1C}" })
            .joined(separator: "\u{1F}")
    }
}

extension KeyLayer {
    /// The rows that run on their own press (#1871): every binding
    /// but the sequences.
    public var pressBindings: [KeyBinding] {
        bindings.filter { !$0.isSequence }
    }

    /// The layer's sequences, each keyed by its leader chord.
    public var sequences: [KeyBinding] {
        bindings.filter(\.isSequence)
    }

    /// Every binding that runs an action: the press rows, then each
    /// sequence's end keys. A reader asking "is this action bound"
    /// takes this; one registering hotkeys takes `pressBindings`.
    public var actionBindings: [KeyBinding] {
        pressBindings + sequences.flatMap(\.endKeys).map(\.binding)
    }

    /// The same layer with every end key passed through `transform`
    /// (`KeyBinding.mappingEndKeys`); press rows pass through it as
    /// well, so one call rewrites every action the layer runs.
    public func mappingActions(
        _ transform: (KeyBinding) -> KeyBinding?
    ) -> KeyLayer {
        var layer = self
        layer.bindings = bindings.compactMap { $0.mappingEndKeys(transform) }
        return layer
    }
}

extension KeyBinding {
    /// The key of `step` already on `combo`, nil where none is: one
    /// step holds one key per chord, held modifiers included (#1871
    /// ▸ step keys). Settings' recorder and the `shortcut.*`
    /// sequence verbs both ask it (#3174); `besides` leaves the key
    /// being edited out.
    public static func stepKey(
        holding combo: String,
        in step: [KeyBinding],
        besides id: UUID? = nil
    ) -> KeyBinding? {
        guard !combo.isEmpty else { return nil }
        return step.first {
            $0.id != id && !$0.combo.isEmpty
                && KeyCombo.equivalent($0.combo, combo)
        }
    }
}
