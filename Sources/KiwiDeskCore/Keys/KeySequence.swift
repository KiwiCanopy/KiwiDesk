import Carbon.HIToolbox
import Foundation

/// One key sequence as the keyboard tap runs it (#1871): a leader
/// chord and the keys each step offers, every end key holding the
/// Lua ref it fires. A pure value, read on the tap thread.
struct KeySequence: Equatable, Sendable {
    /// One key in a step: its chord, the stored binding it was built
    /// from (its spelling names the hint panel's path; its `lua` and
    /// `steps` stand unread), and what pressing it does.
    struct Key: Equatable, Sendable {
        var combo: KeyCombo
        var source: KeyBinding
        var action: Action

        var stored: String { source.combo }

        /// A key built from its spelling alone, as Lua defines one.
        init(combo: KeyCombo, source: KeyBinding, action: Action) {
            self.combo = combo
            self.source = source
            self.action = action
        }

        init(combo: KeyCombo, stored: String, action: Action) {
            self.combo = combo
            if case .opens = action {
                source = .sequence(combo: stored)
            } else {
                source = KeyBinding(combo: stored)
            }
            self.action = action
        }
    }

    indirect enum Action: Equatable, Sendable {
        case run(ref: Int32)
        case opens([Key])
    }

    var leader: KeyCombo
    /// The leader's stored binding, `steps` and `lua` unread.
    var source: KeyBinding
    var steps: [Key]

    init(leader: KeyCombo, source: KeyBinding, steps: [Key]) {
        self.leader = leader
        self.source = source
        self.steps = steps
    }

    /// A sequence from its leader's spelling alone.
    init(leader: KeyCombo, stored: String, steps: [Key]) {
        self.init(
            leader: leader,
            source: .sequence(combo: stored),
            steps: steps
        )
    }

    var stored: String { source.combo }
    /// The leader's name: the hint panel's title.
    var label: String { source.label }
    var meta: KeyBindingMeta { source.meta }

    /// Whether `combo` may be a step key: a key-down the tap can
    /// match, never a modifier tap, a Hyper chord (no held state
    /// reaches the tap) or the plain esc and ⌫ the router keeps.
    static func admitsStep(_ combo: KeyCombo) -> Bool {
        !combo.isTap && admitsLeader(combo)
            && !(combo.modifiers.isEmpty
                && [UInt32(kVK_Escape), UInt32(kVK_Delete)]
                    .contains(combo.keyCode))
    }

    /// Whether `combo` may lead a sequence: anything but Hyper.
    static func admitsLeader(_ combo: KeyCombo) -> Bool {
        !combo.modifiers.contains(.hyper)
    }

    /// The stored binding this runs, each end key's Lua read back
    /// through `body` — what the Lua importer recovers.
    func binding(body: (Int32) -> String) -> KeyBinding {
        var node = source
        node.lua = ""
        node.steps = Self.bindings(steps, body: body)
        return node
    }

    /// The stored binding this runs, its end keys' own Lua kept: the
    /// tree the router answers, which the hint panel reads too.
    var pruned: KeyBinding {
        var node = source
        node.steps = Self.prunedRows(steps)
        return node
    }

    private static func bindings(
        _ keys: [Key],
        body: (Int32) -> String
    ) -> [KeyBinding] {
        keys.map { key in
            var row = key.source
            switch key.action {
            case .run(let ref): row.lua = body(ref)
            case .opens(let next): row.steps = bindings(next, body: body)
            }
            return row
        }
    }

    private static func prunedRows(_ keys: [Key]) -> [KeyBinding] {
        keys.map { key in
            var row = key.source
            if case .opens(let next) = key.action {
                row.steps = prunedRows(next)
            }
            return row
        }
    }

    /// Every ref the sequence holds, for release.
    var refs: [Int32] { Self.refs(in: steps) }

    static func refs(in keys: [Key]) -> [Int32] {
        keys.flatMap { key -> [Int32] in
            switch key.action {
            case .run(let ref): [ref]
            case .opens(let next): refs(in: next)
            }
        }
    }

    /// Builds the runtime tree from a stored `.sequence` binding,
    /// minting each end key's ref through `compile`. A key the tap
    /// cannot answer, whose chord does not parse, or whose Lua
    /// `compile` refuses (nil) is left out and named in `skipped`;
    /// in one step the last of two keys on one chord wins, as a
    /// layer's rows do, the loser's refs handed to `release`.
    static func build(
        _ binding: KeyBinding,
        compile: (KeyBinding) -> Int32?,
        release: (Int32) -> Void
    ) -> (sequence: KeySequence?, skipped: [String]) {
        guard binding.isSequence,
            let leader = KeyCombo.parse(binding.combo),
            admitsLeader(leader)
        else { return (nil, [binding.combo]) }
        var skipped: [String] = []
        let steps = keys(
            binding.steps ?? [],
            compile: compile,
            release: release,
            skipped: &skipped
        )
        var source = binding
        source.steps = []
        return (
            KeySequence(leader: leader, source: source, steps: steps),
            skipped
        )
    }

    private static func keys(
        _ bindings: [KeyBinding],
        compile: (KeyBinding) -> Int32?,
        release: (Int32) -> Void,
        skipped: inout [String]
    ) -> [Key] {
        var built: [Key] = []
        for binding in bindings where !binding.combo.isEmpty {
            guard let combo = KeyCombo.parse(binding.combo),
                admitsStep(combo)
            else {
                skipped.append(binding.combo)
                continue
            }
            let action: Action
            if binding.isSequence {
                action = .opens(
                    keys(
                        binding.steps ?? [],
                        compile: compile,
                        release: release,
                        skipped: &skipped
                    )
                )
            } else if let ref = compile(binding) {
                action = .run(ref: ref)
            } else {
                skipped.append(binding.combo)
                continue
            }
            for lost in built where lost.combo == combo {
                skipped.append(lost.stored)
                refs(in: [lost]).forEach(release)
            }
            built.removeAll { $0.combo == combo }
            var source = binding
            if source.isSequence { source.steps = [] }
            built.append(Key(combo: combo, source: source, action: action))
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

    public init(leader: String, path: [String]) {
        self.leader = leader
        self.path = path
    }
}
