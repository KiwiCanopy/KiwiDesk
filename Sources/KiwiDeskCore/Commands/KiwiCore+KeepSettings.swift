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
            return .fail(
                "stale epoch: the live settings were replaced since "
                    + "that report"
            )
        }
        let unique = Set(paths).sorted { $0.lexicographicallyPrecedes($1) }
        let judge = keepJudge()
        let verdicts = unique.compactMap(judge.verdict(of:))
        let wanted = verdicts.filter { $0.notKeepable == nil && !$0.stored }
        var refused = verdicts.filter { $0.notKeepable != nil }
        let (leaves, undecodable) = keptLeaves(wanted, judge)
        refused += undecodable
        let skipped = Set(undecodable.map(\.id))
        let attempted = wanted.filter { !skipped.contains($0.id) }
        if !attempted.isEmpty {
            writeThroughLiveProfile(.kept(leaves))
        }
        // Judged again after the write: kept is what landed.
        let after = keepJudge()
        var kept = verdicts.filter { $0.notKeepable == nil && $0.stored }
        for leaf in attempted {
            let landed =
                KeepPointer.path(leaf.id)
                .flatMap(after.verdict(of:))?.stored ?? false
            if landed {
                kept.append(leaf)
            } else {
                refused.append(Self.unwritten(leaf))
            }
        }
        return .ok(keepAnswer(kept: kept, refused: refused))
    }

    /// The live values of `leaves`, and those whose settings could
    /// not be laid over the stored profile together.
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
        kept.settings = [:]
        return (kept, settingsLeaves.map(Self.unwritten))
    }

    private static func unwritten(_ leaf: TouchedLeaf) -> TouchedLeaf {
        TouchedLeaf(id: leaf.id, owner: leaf.owner, notKeepable: .notWritten)
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
