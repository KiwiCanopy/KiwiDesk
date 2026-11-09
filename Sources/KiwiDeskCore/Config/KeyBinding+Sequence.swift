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
