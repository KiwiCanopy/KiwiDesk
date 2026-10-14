import Foundation

/// `keep_settings` (#1685 ▸ Ruling 4): the leaves a change report
/// named, written as they are live NOW into the live profile — one
/// `LiveProfileEdit` through `writeThroughLiveProfile`, whose
/// `recordLookWrite` lands a follower's look leaves in the shared
/// look. Never `save_profile`, which snapshots everything live.
extension KiwiCore {
    func keepSettings(_ args: [JSONValue]) -> CommandResponse {
        let ids = args.compactMap(\.stringValue)
        let paths = Set(ids.compactMap(KeepPointer.path(_:)))
        guard !ids.isEmpty, paths.count == Set(ids).count,
            ids.count == args.count
        else {
            return .fail("expected leaf ids from a change report")
        }
        let verdicts = touchedLeaves(
            paths.sorted { $0.lexicographicallyPrecedes($1) }
        )
        let live = keepDocument
        var leaves = KeptLeaves()
        for verdict in verdicts where verdict.notKeepable == nil {
            guard let path = KeepPointer.path(verdict.id) else { continue }
            let rest = Array(path.dropFirst())
            if path.first == KeepRoot.spaceModes {
                let mode = KeepPointer.value(at: path, in: live)?
                    .stringValue.flatMap(LayoutMode.init(rawValue:))
                if let mode { leaves.spaceModes[SpaceID(rest[0])] = mode }
            } else {
                leaves.settings[rest] = .some(
                    KeepPointer.value(at: path, in: live)
                )
            }
        }
        let kept = verdicts.filter { $0.notKeepable == nil }
        if !kept.isEmpty, !writeThroughLiveProfile(.kept(leaves)) {
            return .fail("the live profile's file was not written")
        }
        return .ok(keepAnswer(verdicts, kept: kept))
    }

    private func keepAnswer(
        _ verdicts: [TouchedLeaf],
        kept: [TouchedLeaf]
    ) -> JSONValue {
        var answer: [String: JSONValue] = [
            "kept": .array(kept.map(Self.json)),
            "not_keepable": .array(
                verdicts.filter { $0.notKeepable != nil }.map(Self.json)
            ),
        ]
        if let name = profiles.currentName {
            answer["profile"] = .string(name)
        }
        // A shared-look leaf reaches every profile wearing it.
        if kept.contains(where: { $0.owner == .sharedLook }) {
            answer["followers"] = .array(
                profiles.list().filter {
                    (try? profiles.read(name: $0))?.look == nil
                }.map(JSONValue.string)
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
