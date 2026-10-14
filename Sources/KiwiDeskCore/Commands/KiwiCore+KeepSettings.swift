import Foundation

/// `keep_settings` (#1685 ▸ Ruling 4): the leaves a change report
/// named, written as they are live NOW into the live profile — one
/// `LiveProfileEdit` through `writeThroughLiveProfile`, whose
/// `recordLookWrite` lands a follower's look leaves in the shared
/// look. Never `save_profile`, which snapshots everything live.
/// What it answers as kept is re-judged after the write, so a
/// write that did not land is never told as kept.
extension KiwiCore {
    /// The verb's name, read by the MCP `keep` tool and its `run`
    /// refusal so a rename cannot leave either aimed at a dead verb.
    nonisolated public static let keepSettingsCommand = "keep_settings"

    /// The refusal of a keep whose epoch a replacement moved past;
    /// the MCP `keep` tool tells the model to retry on it.
    nonisolated public static let staleKeepRefusal =
        "stale epoch: the live settings were replaced since that report"

    /// `keep_settings(epoch, id…)`: refused whole where `epoch` is
    /// not the live one, since the ids then name values a load
    /// already replaced.
    func keepSettings(_ args: [JSONValue]) -> CommandResponse {
        let strings = args.compactMap(\.stringValue)
        let paths = strings.dropFirst().compactMap(KeepPointer.path(_:))
        guard strings.count == args.count, strings.count >= 2,
            paths.count == strings.count - 1
        else {
            return .fail("expected an epoch and leaf ids from a report")
        }
        guard strings[0] == settingsEpoch else {
            return .fail(Self.staleKeepRefusal)
        }
        let unique = Set(paths).sorted { $0.lexicographicallyPrecedes($1) }
        let judge = keepJudge()
        let verdicts = unique.compactMap(judge.verdict(of:))
        let wanted = verdicts.filter { $0.notKeepable == nil && !$0.stored }
        var refused = verdicts.filter { $0.notKeepable != nil }
        let (leaves, conflicting) = keptLeaves(wanted, judge)
        refused += conflicting
        let skipped = Set(conflicting.map(\.id))
        let attempted = wanted.filter { !skipped.contains($0.id) }
        if !leaves.isEmpty {
            // A keep writes files; nothing live moves (#1685).
            preservingLiveSettings {
                writeThroughLiveProfile(.kept(leaves))
            }
        }
        // Judged again after the write: kept is what landed.
        let after = keepJudge()
        var kept = verdicts.filter { $0.notKeepable == nil && $0.stored }
        for leaf in attempted {
            let landed = KeepPointer.path(leaf.id).map(after.holds) ?? false
            if landed {
                kept.append(leaf)
            } else {
                refused.append(Self.unwritten(leaf))
            }
        }
        return .ok(keepAnswer(kept: kept, refused: refused))
    }

    /// The live values of `leaves`, and those that cannot be laid
    /// over the stored profile: where the whole set does not decode,
    /// each leaf that fails alone, then the rest if they still fail
    /// together.
    private func keptLeaves(
        _ leaves: [TouchedLeaf],
        _ judge: KeepJudge
    ) -> (KeptLeaves, [TouchedLeaf]) {
        var kept = KeptLeaves()
        var settingsLeaves: [TouchedLeaf] = []
        for leaf in leaves {
            guard let path = KeepPointer.path(leaf.id) else { continue }
            let value = KeepPointer.value(at: path, in: judge.live)
            let rest = Array(path.dropFirst())
            if path.first == KeepRoot.spaceModes {
                if let mode = value?.stringValue
                    .flatMap(LayoutMode.init(rawValue:))
                {
                    kept.spaceModes[SpaceID(rest[0])] = mode
                }
            } else {
                kept.settings[rest] = .some(value)
                settingsLeaves.append(leaf)
            }
        }
        let stored = profiles.currentName.flatMap {
            try? profiles.read(name: $0)
        }
        guard !kept.settings.isEmpty, let stored,
            stored.settings.patched(kept.settings) == nil
        else { return (kept, []) }
        var refused: [TouchedLeaf] = []
        for leaf in settingsLeaves {
            guard let path = KeepPointer.path(leaf.id) else { continue }
            let rest = Array(path.dropFirst())
            let alone = kept.settings.filter { $0.key == rest }
            if stored.settings.patched(alone) == nil {
                kept.settings[rest] = nil
                refused.append(Self.refused(leaf, .conflicting))
            }
        }
        if stored.settings.patched(kept.settings) == nil {
            let rest = settingsLeaves.filter { leaf in
                !refused.contains { $0.id == leaf.id }
            }
            refused += rest.map { Self.refused($0, .conflicting) }
            kept.settings = [:]
        }
        return (kept, refused)
    }

    private static func refused(
        _ leaf: TouchedLeaf,
        _ reason: NotKeepable
    ) -> TouchedLeaf {
        TouchedLeaf(id: leaf.id, owner: leaf.owner, notKeepable: reason)
    }

    private static func unwritten(_ leaf: TouchedLeaf) -> TouchedLeaf {
        refused(leaf, .notWritten)
    }

    private func keepAnswer(
        kept: [TouchedLeaf],
        refused: [TouchedLeaf]
    ) -> JSONValue {
        let byID: (TouchedLeaf, TouchedLeaf) -> Bool = { $0.id < $1.id }
        var answer: [String: JSONValue] = [
            "epoch": .string(settingsEpoch),
            "kept": .array(kept.sorted(by: byID).map(Self.json)),
            "not_keepable": .array(refused.sorted(by: byID).map(Self.json)),
        ]
        if let name = profiles.currentName {
            answer["profile"] = .string(name)
        }
        // A shared-look leaf reaches every profile wearing it.
        if kept.contains(where: { $0.owner == .sharedLook }) {
            answer["followers"] = .array(
                followingProfiles().map { .string($0.name) }
            )
        }
        return .object(answer)
    }

    private static func json(_ leaf: TouchedLeaf) -> JSONValue {
        var fields: [String: JSONValue] = [
            "id": .string(leaf.id),
            "owner": .string(leaf.owner.rawValue),
        ]
        if let refusal = leaf.notKeepable {
            fields["not_keepable"] = .string(refusal.rawValue)
        }
        return .object(fields)
    }
}
