import Foundation

/// The crossings a lens rename or delete owes a profile's sparse
/// `lens_reach` (#2103 rulings 38, 39): a mark keyed by a name no
/// lens carries would leave a later lens of that name out.
extension VisionLens {
    /// `reach` after the lens `old` is renamed `new`: its mark,
    /// or its absence, moves to the new key, so a stale mark of the
    /// new name never carries over.
    public static func reach(
        _ reach: [String: Bool]?,
        renaming old: String,
        to new: String
    ) -> [String: Bool]? {
        guard var reach else { return nil }
        let mark = reach.removeValue(forKey: reachKey(old))
        reach[reachKey(new)] = mark
        return reach.isEmpty ? nil : reach
    }

    /// `reach` after the lens `name` is deleted: its mark goes, and
    /// an emptied map is no map, as the sparse encoding stores it.
    public static func reach(
        _ reach: [String: Bool]?,
        deleting name: String
    ) -> [String: Bool]? {
        guard var reach else { return nil }
        reach[reachKey(name)] = nil
        return reach.isEmpty ? nil : reach
    }
}

extension AppWideSettings {
    /// Whether two spellings name one lens: the comparison every
    /// lens lookup, crossing and binding match takes (ruling 39).
    public static func sameLens(_ lhs: String, _ rhs: String) -> Bool {
        VisionLens.reachKey(lhs) == VisionLens.reachKey(rhs)
    }
}
