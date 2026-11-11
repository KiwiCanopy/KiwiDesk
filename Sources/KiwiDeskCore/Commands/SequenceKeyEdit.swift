import Foundation

/// The `shortcut.*` sequence verbs' edits on one stored tree (#3174
/// ▸ Ruling), one key at a time as Settings' Add Key makes them. A
/// path is the step keys under the leader, as stored; a key is found
/// at its step through Core's one sibling rule
/// (`KeyBinding.stepKey`), and admitted through the router's own
/// (`KeySequence.admitsStep`). Pure: no store, no page.
enum SequenceKeyEdit {
    struct Refusal: Error, Equatable {
        let reason: String
    }

    /// `path` read from a CLI `w,h` or a JSON list, each key spelled
    /// as the recorder stores it; nil where a key does not parse.
    static func path(_ value: JSONValue?) -> [String]? {
        let parts: [String]
        switch value {
        case .string(let text):
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            parts =
                trimmed.isEmpty
                ? []
                : trimmed.split(
                    separator: ",",
                    omittingEmptySubsequences: false
                ).map(String.init)
        case .array(let list):
            parts = list.compactMap(\.stringValue)
            guard parts.count == list.count else { return nil }
        default:
            return nil
        }
        var keys: [String] = []
        for part in parts {
            guard
                let spelled = KeyCombo.parse(
                    part.trimmingCharacters(in: .whitespaces)
                )?.comboString()
            else { return nil }
            keys.append(spelled)
        }
        return keys
    }

    /// The first key of `path` the router never matches under
    /// `leader`, refused by naming it.
    static func admission(_ path: [String], under leader: String)
        -> Refusal?
    {
        guard let lead = KeyCombo.parse(leader) else { return nil }
        guard KeySequence.admitsLeader(lead) else {
            return Refusal(
                reason: "a key sequence can't start on a Hyper chord"
            )
        }
        for key in path {
            guard let combo = KeyCombo.parse(key),
                KeySequence.admitsStep(combo, under: lead)
            else {
                return Refusal(
                    reason: "\(key) can't be a key in a sequence: a "
                        + "modifier tapped alone, a Hyper chord, the "
                        + "leader, or esc or delete on its own"
                )
            }
        }
        return nil
    }

    /// `root` with `key` at the end of `path`, every missing key on
    /// the way made a key that opens more. Never replaces: a key
    /// already on that step, or a path through a key that runs a
    /// command, is refused.
    static func adding(
        _ key: KeyBinding,
        at path: [String],
        in root: KeyBinding,
        walked: [String] = []
    ) -> Result<KeyBinding, Refusal> {
        guard let first = path.first else {
            return .failure(Refusal(reason: "expected a path of keys"))
        }
        let here = walked + [first]
        var node = root
        var steps = node.steps ?? []
        let held = KeyBinding.stepKey(holding: first, in: steps)
        if path.count == 1 {
            guard held == nil else {
                return .failure(
                    Refusal(
                        reason: "\(spelled(here)) is already bound in "
                            + "this sequence; remove it first"
                    )
                )
            }
            var added = key
            added.combo = first
            steps.append(added)
            node.steps = steps
            return .success(node)
        }
        var branch = held ?? .sequence(combo: first)
        guard branch.isSequence else {
            return .failure(
                Refusal(
                    reason: "\(spelled(here)) runs a command, so it opens "
                        + "no keys; remove it first"
                )
            )
        }
        switch adding(
            key,
            at: Array(path.dropFirst()),
            in: branch,
            walked: here
        ) {
        case .failure(let refusal):
            return .failure(refusal)
        case .success(let grown):
            branch = grown
        }
        if let at = steps.firstIndex(where: { $0.id == held?.id }) {
            steps[at] = branch
        } else {
            steps.append(branch)
        }
        node.steps = steps
        return .success(node)
    }

    /// `root` with the node at `path` passed through `edit`; the
    /// leader itself for an empty path.
    static func updating(
        at path: [String],
        in root: KeyBinding,
        walked: [String] = [],
        _ edit: (inout KeyBinding) -> Refusal?
    ) -> Result<KeyBinding, Refusal> {
        var node = root
        guard let first = path.first else {
            if let refusal = edit(&node) { return .failure(refusal) }
            return .success(node)
        }
        let here = walked + [first]
        var steps = node.steps ?? []
        guard let held = KeyBinding.stepKey(holding: first, in: steps),
            let at = steps.firstIndex(where: { $0.id == held.id })
        else {
            return .failure(
                Refusal(reason: "no key on \(spelled(here)) in this sequence")
            )
        }
        switch updating(
            at: Array(path.dropFirst()),
            in: held,
            walked: here,
            edit
        ) {
        case .failure(let refusal):
            return .failure(refusal)
        case .success(let changed):
            steps[at] = changed
        }
        node.steps = steps
        return .success(node)
    }

    /// `root` without the key at `path`, everything under it with it.
    static func removing(at path: [String], from root: KeyBinding)
        -> Result<KeyBinding, Refusal>
    {
        guard let last = path.last else {
            return .failure(Refusal(reason: "expected a path of keys"))
        }
        return updating(at: Array(path.dropLast()), in: root) { parent in
            guard parent.isSequence,
                let held = KeyBinding.stepKey(
                    holding: last,
                    in: parent.steps ?? []
                )
            else {
                return Refusal(
                    reason: "no key on \(spelled(path)) in this sequence"
                )
            }
            parent.steps?.removeAll { $0.id == held.id }
            return nil
        }
    }

    static func spelled(_ path: [String]) -> String {
        path.joined(separator: ",")
    }
}
