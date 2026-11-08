import Carbon.HIToolbox
import Foundation

/// One key sequence as the keyboard tap runs it (#1871): a leader
/// chord and the keys each step offers, every end key holding the
/// Lua ref it fires. A pure value, read on the tap thread.
struct KeySequence: Equatable, Sendable {
    /// One key in a step: its chord, its stored spelling (what the
    /// hint panel's path names), what pressing it does, and its
    /// name and meta, which the Lua importer reads back.
    struct Key: Equatable, Sendable {
        var combo: KeyCombo
        var stored: String
        var action: Action
        var label = ""
        var meta = KeyBindingMeta.none
    }

    indirect enum Action: Equatable, Sendable {
        case run(ref: Int32)
        case opens([Key])
    }

    var leader: KeyCombo
    var stored: String
    var steps: [Key]
    /// The leader's name: the hint panel's title.
    var label = ""
    var meta = KeyBindingMeta.none

    /// The stored binding this runs, each end key's Lua read back
    /// through `body` — what the Lua importer recovers (#1871).
    func binding(body: (Int32) -> String) -> KeyBinding {
        var node = KeyBinding.sequence(
            combo: stored,
            label: label,
            steps: Self.bindings(steps, body: body)
        )
        node.meta = meta
        return node
    }

    private static func bindings(
        _ keys: [Key],
        body: (Int32) -> String
    ) -> [KeyBinding] {
        keys.map { key in
            var row: KeyBinding
            switch key.action {
            case .run(let ref):
                row = KeyBinding(
                    combo: key.stored,
                    lua: body(ref),
                    label: key.label
                )
            case .opens(let next):
                row = .sequence(
                    combo: key.stored,
                    label: key.label,
                    steps: bindings(next, body: body)
                )
            }
            row.meta = key.meta
            return row
        }
    }

    /// Every ref the sequence holds, for release.
    var refs: [Int32] { Self.refs(in: steps) }

    private static func refs(in keys: [Key]) -> [Int32] {
        keys.flatMap { key -> [Int32] in
            switch key.action {
            case .run(let ref): [ref]
            case .opens(let next): refs(in: next)
            }
        }
    }

    /// Builds the runtime tree from a stored `.sequence` binding,
    /// minting each end key's ref through `compile`. An end key
    /// whose chord does not parse, or whose Lua `compile` refuses
    /// (nil), is left out and named in `skipped`; in one step the
    /// last of two keys on one chord wins, as a layer's rows do.
    static func build(
        _ binding: KeyBinding,
        compile: (KeyBinding) -> Int32?
    ) -> (sequence: KeySequence?, skipped: [String]) {
        guard binding.isSequence, let leader = KeyCombo.parse(binding.combo)
        else { return (nil, [binding.combo]) }
        var skipped: [String] = []
        let steps = keys(
            binding.steps ?? [],
            compile: compile,
            skipped: &skipped
        )
        return (
            KeySequence(
                leader: leader,
                stored: binding.combo,
                steps: steps,
                label: binding.label,
                meta: binding.meta
            ),
            skipped
        )
    }

    private static func keys(
        _ bindings: [KeyBinding],
        compile: (KeyBinding) -> Int32?,
        skipped: inout [String]
    ) -> [Key] {
        var built: [Key] = []
        for binding in bindings where !binding.combo.isEmpty {
            guard let combo = KeyCombo.parse(binding.combo) else {
                skipped.append(binding.combo)
                continue
            }
            let action: Action
            if binding.isSequence {
                action = .opens(
                    keys(
                        binding.steps ?? [],
                        compile: compile,
                        skipped: &skipped
                    )
                )
            } else if let ref = compile(binding) {
                action = .run(ref: ref)
            } else {
                skipped.append(binding.combo)
                continue
            }
            built.removeAll { $0.combo == combo }
            built.append(
                Key(
                    combo: combo,
                    stored: binding.combo,
                    action: action,
                    label: binding.label,
                    meta: binding.meta
                )
            )
        }
        return built
    }
}

/// Where an open sequence stands, for the hint panel (#1871): the
/// leader's stored chord and the step keys pressed since, as
/// stored. Core names the path; the GUI reads the tree it names.
public struct KeySequenceProgress: Equatable, Sendable {
    public var leader: String
    public var path: [String]
}
