import Foundation

/// Turns a stored `animations.on_space_change: false` on once, in a
/// file below the floor (#1931, `SpaceChangeOnMigrationTests`): the
/// leaf's MEANING changed under the same key — before 2.2.0 it slid
/// the windows themselves, now it plays the plate slide — and an
/// encoder that writes `animations` whole stored the old default in
/// nearly every file. A group whose other master leaves are all off
/// reads as the master switched off and keeps its `false`.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let spaceChangeGroupKey = "animations"
    static let spaceChangeLeafKey = "on_space_change"
    /// The master's other leaves (`AnimationSettings.anyEnabled`).
    static let spaceChangeMasterLeaves = [
        "on_window_resize", "on_window_swap", "on_relayout",
    ]
    /// The formats this step introduced, a profile's and a
    /// bundle's: a turned-on `true` is the same bytes as a chosen
    /// one, so without this gate a `false` chosen after the
    /// crossing would be turned on again by the next bump.
    static let spaceChangeOnProfileFormat = 19
    static let spaceChangeOnBundleFormat = 24

    @Sendable
    static func migratingSpaceChangeOn(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: spaceChangeOnProfileFormat,
                bundle: spaceChangeOnBundleFormat
            )
        else { return nil }
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(spaceChangeLeafKey)\"".utf8))
                    != nil
            },
            rewriting: {
                rewritingValues(of: $0, at: spaceChangeGroupKey) {
                    ($0 as? [String: Any]).flatMap(turnedOnSpaceChange)
                }
            },
            editing: surgicallyTurnedOnSpaceChange
        )
    }

    /// `group` with the leaf turned on, or nil where it stays: the
    /// leaf already on or absent, or every master leaf off.
    static func turnedOnSpaceChange(
        _ group: [String: Any]
    ) -> [String: Any]? {
        guard group[spaceChangeLeafKey] as? Bool == false,
            spaceChangeMasterLeaves.contains(where: {
                group[$0] as? Bool ?? true
            })
        else { return nil }
        var out = group
        out[spaceChangeLeafKey] = true
        return out
    }

    /// The textual edit: each `animations` object the walk would
    /// turn on has its leaf's `false` replaced where it stands. The
    /// group holds no nested object, so one brace pair bounds it.
    private static func surgicallyTurnedOnSpaceChange(
        _ text: String
    ) -> Data? {
        guard
            let regex = try? NSRegularExpression(
                pattern: "\"\(spaceChangeGroupKey)\"\\s*:\\s*(\\{[^{}]*\\})"
            )
        else { return nil }
        var out = text
        let whole = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: whole).reversed() {
            guard let range = Range(match.range(at: 1), in: out),
                let group = try? JSONSerialization.jsonObject(
                    with: Data(out[range].utf8)
                ) as? [String: Any],
                turnedOnSpaceChange(group) != nil
            else { continue }
            out.replaceSubrange(
                range,
                with: out[range].replacingOccurrences(
                    of: "(\"\(spaceChangeLeafKey)\"\\s*:\\s*)false",
                    with: "$1true",
                    options: .regularExpression
                )
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
