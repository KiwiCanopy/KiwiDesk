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

        init(combo: KeyCombo, source: KeyBinding, action: Action) {
            self.combo = combo
            self.source = source
            self.action = action
        }

        #if DEBUG
            /// Tests only: a key from its spelling alone.
            init(combo: KeyCombo, stored: String, action: Action) {
                self.combo = combo
                if case .opens = action {
                    source = .sequence(combo: stored)
                } else {
                    source = KeyBinding(combo: stored)
                }
                self.action = action
            }
        #endif
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

    #if DEBUG
        /// Tests only: a sequence from its leader's spelling alone.
        init(leader: KeyCombo, stored: String, steps: [Key]) {
            self.init(
                leader: leader,
                source: .sequence(combo: stored),
                steps: steps
            )
        }
    #endif

    var stored: String { source.combo }
    /// The leader's name: the hint panel's title.
    var label: String { source.label }
    var meta: KeyBindingMeta { source.meta }

    /// Whether `combo` may be a step key under `leader`: a key-down
    /// the tap can match, never a modifier tap, a Hyper chord (no
    /// held state reaches the tap), the leader itself, or the plain
    /// esc and ⌫ the router keeps.
    static func admitsStep(_ combo: KeyCombo, under leader: KeyCombo)
        -> Bool
    {
        !combo.isTap && admitsLeader(combo) && combo != leader
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

    /// Appends `key` to a step, the last of two keys on one chord
    /// winning as a layer's last row does: the loser's refs go to
    /// `release`, and its spelling is returned.
    static func keepLast(
        _ key: Key,
        in step: inout [Key],
        release: (Int32) -> Void
    ) -> [String] {
        let lost = step.filter { $0.combo == key.combo }
        refs(in: lost).forEach(release)
        step.removeAll { $0.combo == key.combo }
        step.append(key)
        return lost.map(\.stored)
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
            leader: leader,
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
        leader: KeyCombo,
        compile: (KeyBinding) -> Int32?,
        release: (Int32) -> Void,
        skipped: inout [String]
    ) -> [Key] {
        var built: [Key] = []
        for binding in bindings where !binding.combo.isEmpty {
            guard let combo = KeyCombo.parse(binding.combo),
                admitsStep(combo, under: leader)
            else {
                skipped.append(binding.combo)
                continue
            }
            let action: Action
            if binding.isSequence {
                action = .opens(
                    keys(
                        binding.steps ?? [],
                        leader: leader,
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
            var source = binding
            if source.isSequence { source.steps = [] }
            skipped += keepLast(
                Key(combo: combo, source: source, action: action),
                in: &built,
                release: release
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

    public init(leader: String, path: [String]) {
        self.leader = leader
        self.path = path
    }
}
