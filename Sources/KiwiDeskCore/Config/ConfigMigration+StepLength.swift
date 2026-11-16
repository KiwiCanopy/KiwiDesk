import Foundation

/// Drops a stored `step_distance` from every `scroll_gesture` group
/// (#1873 ▸ Ruling 2026-11-16): a long swipe's steps count finger
/// travel in mm under the new `step_length`, and the point value
/// carries no meaning across. The base encodes whole, so a stored
/// value records a save, not a choice, and everyone takes the new
/// default; a profile's sparse value is dropped too, its unit gone.
/// Removing an absent key is a no-op, so the step needs no format
/// gate (`StepLengthMigrationTests`).
extension ConfigMigration {
    static let retiredStepDistanceKey = "step_distance"

    @Sendable
    static func migratingStepDistanceOut(_ data: Data) -> Data? {
        let needle = Data("\"\(retiredStepDistanceKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: withoutStepDistance,
            editing: stepDistanceTextOut
        )
    }

    /// Every `scroll_gesture` object, at any depth, loses the key.
    static func withoutStepDistance(_ node: Any) -> (Any, Bool) {
        if var dict = node as? [String: Any] {
            var changed = false
            for (key, value) in dict {
                var (child, childChanged) = withoutStepDistance(value)
                if key == longSwipesGroupKey,
                    var group = child as? [String: Any],
                    group.removeValue(forKey: retiredStepDistanceKey) != nil
                {
                    child = group
                    childChanged = true
                }
                if childChanged {
                    dict[key] = child
                    changed = true
                }
            }
            return (dict, changed)
        }
        if var array = node as? [Any] {
            var changed = false
            for (index, value) in array.enumerated() {
                let (child, childChanged) = withoutStepDistance(value)
                if childChanged {
                    array[index] = child
                    changed = true
                }
            }
            return (array, changed)
        }
        return (node, false)
    }

    /// Deletes each member, with one comma and the space after it,
    /// found through `JSONKeyLexer` inside an object written under
    /// `scroll_gesture`; nil where there is none, and the walk's
    /// output stands in.
    static func stepDistanceTextOut(_ text: String) -> Data? {
        let bytes = Array(text.utf8)
        let hits = JSONKeyLexer.entries(in: text).filter { entry in
            entry.key == retiredStepDistanceKey
                && isScrollGestureObject(entry.object, in: bytes)
        }
        guard !hits.isEmpty else { return nil }
        let space: Set<UInt8> = Set(" \n\t\r".utf8)
        var out = bytes
        for hit in hits.sorted(by: { $0.keyStart > $1.keyStart }) {
            var start = hit.keyStart
            var end = hit.valueRange.upperBound
            var after = end
            while after < out.count, space.contains(out[after]) {
                after += 1
            }
            if after < out.count, out[after] == UInt8(ascii: ",") {
                end = after + 1
                while end < out.count, space.contains(out[end]) {
                    end += 1
                }
            } else {
                var before = start - 1
                while before >= 0, space.contains(out[before]) {
                    before -= 1
                }
                guard before >= 0, out[before] == UInt8(ascii: ",")
                else {
                    // The group's one member: leave the braces.
                    out.removeSubrange(start..<end)
                    continue
                }
                start = before
            }
            out.removeSubrange(start..<end)
        }
        return Data(out)
    }
}
