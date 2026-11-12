import Foundation

/// The animation lengths' retired per-profile spelling (#3237): read
/// once by `KiwiCore.prepareAppWide` and dropped from every profile
/// file when their crossing ends. A crossing of its own beside
/// #1741's, which an install that adopted has already ended.
extension ConfigMigration {
    /// The keys under a profile's `settings.animations`, spelled
    /// here rather than derived: `AnimationSettings` no longer
    /// declares them.
    static let retiredPaceKeys = [
        "duration", "scroll_duration", "expand_duration",
        "reveal_duration",
    ]
    static let paceGroupKey = "animations"
    /// A key only the per-profile group carries, which tells its
    /// object apart from any other holding a `duration`.
    static let paceGroupMarker = "on_window_swap"

    /// The lengths a profile file carries, read from its MIGRATED
    /// bytes (profiles.md: a key a step rewrites is read after it),
    /// nil when it carries none.
    static func legacyPace(
        inProfile data: Data
    ) -> AppWideSettings.Animations? {
        let bytes = migrated(data) ?? data
        guard
            let root = try? JSONSerialization.jsonObject(with: bytes)
                as? [String: Any],
            let settings = root[glassSettingsKey] as? [String: Any],
            let group = settings[paceGroupKey] as? [String: Any]
        else { return nil }
        let pace = AppWideSettings.Animations(
            duration: group["duration"] as? Int,
            scrollDuration: group["scroll_duration"] as? Int,
            expandDuration: group["expand_duration"] as? Int,
            revealDuration: group["reveal_duration"] as? Int
        )
        guard
            pace.duration != nil || pace.scrollDuration != nil
                || pace.expandDuration != nil || pace.revealDuration != nil
        else { return nil }
        return pace
    }

    /// The lengths each profile inside a backup carries, by name.
    static func legacyPace(
        inBundle data: Data
    ) -> [String: AppWideSettings.Animations] {
        let bytes = migrated(data) ?? data
        guard
            let root = try? JSONSerialization.jsonObject(with: bytes)
                as? [String: Any],
            let profiles = root["profiles"] as? [[String: Any]]
        else { return [:] }
        var out: [String: AppWideSettings.Animations] = [:]
        for profile in profiles {
            guard let name = profile["name"] as? String,
                let one = try? JSONSerialization.data(
                    withJSONObject: profile
                ),
                let pace = legacyPace(inProfile: one)
            else { continue }
            out[name] = pace
        }
        return out
    }

    /// `data` without the four lengths under `settings.animations`,
    /// or nil when it carries none. Surgical, so the file keeps its
    /// formatting.
    static func withoutLegacyPace(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            rewriting: droppingLegacyPace,
            editing: legacyPaceTextDropped
        )
    }

    private static func droppingLegacyPace(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any],
            var settings = root[glassSettingsKey] as? [String: Any],
            var group = settings[paceGroupKey] as? [String: Any]
        else { return (node, false) }
        var changed = false
        for key in retiredPaceKeys where group[key] != nil {
            group[key] = nil
            changed = true
        }
        settings[paceGroupKey] = group
        root[glassSettingsKey] = settings
        return (root, changed)
    }

    /// Cuts each length's member out of the group's object: the
    /// member and the comma after it, or, for the last, the comma
    /// before it.
    private static func legacyPaceTextDropped(_ text: String) -> Data? {
        let entries = JSONKeyLexer.entries(in: text)
        let groups = Set(
            entries.filter { $0.key == paceGroupMarker }.map(\.object)
        )
        guard groups.count == 1, let group = groups.first else {
            return nil
        }
        let bytes = Array(text.utf8)
        let cuts =
            entries
            .filter {
                $0.object == group && retiredPaceKeys.contains($0.key)
            }
            .map { memberCut($0, in: bytes) }
        guard !cuts.isEmpty else { return nil }
        var out = bytes
        for cut in merged(cuts).reversed() {
            out.removeSubrange(cut)
        }
        return Data(out)
    }

    /// The bytes one member owns.
    static func memberCut(
        _ entry: JSONKeyLexer.Entry,
        in bytes: [UInt8]
    ) -> Range<Int> {
        let space: Set<UInt8> = Set(" \n\t\r".utf8)
        var end = entry.valueRange.upperBound
        var next = end
        while next < bytes.count, space.contains(bytes[next]) { next += 1 }
        if next < bytes.count, bytes[next] == UInt8(ascii: ",") {
            end = next + 1
            while end < bytes.count, space.contains(bytes[end]) { end += 1 }
            return entry.keyStart..<end
        }
        var start = entry.keyStart
        var back = start - 1
        while back >= 0, space.contains(bytes[back]) { back -= 1 }
        if back >= 0, bytes[back] == UInt8(ascii: ",") { start = back }
        return start..<end
    }

    /// `ranges` sorted, overlapping ones joined.
    static func merged(_ ranges: [Range<Int>]) -> [Range<Int>] {
        var out: [Range<Int>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = out.last, range.lowerBound <= last.upperBound {
                out[out.count - 1] =
                    last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                out.append(range)
            }
        }
        return out
    }
}
