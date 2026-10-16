import Foundation

/// The crossings a lens rename or delete owes a profile's sparse
/// `lens_reach` (#2103 rulings 38, 39): a mark keyed by a name no
/// lens carries would leave a later lens of that name out.
extension VisionLens {
    /// `reach` after the lens `old` is renamed `new`: its mark
    /// moves to the new key, replacing any the new key held.
    public static func reach(
        _ reach: [String: Bool]?,
        renaming old: String,
        to new: String
    ) -> [String: Bool]? {
        guard var reach, let mark = reach[reachKey(old)] else {
            return reach
        }
        reach[reachKey(old)] = nil
        reach[reachKey(new)] = mark
        return reach
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
