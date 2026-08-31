import Foundation

/// Monitor-set profile matching queries for ProfileManager.
extension ProfileManager {
    /// Matches live monitor set against stored profiles in priority order.
    public func match(fingerprints: [String]) -> ProfileMatch {
        let profiles = allProfiles()
        if let exact = profiles.first(where: {
            $0.set(matching: fingerprints) != nil
        }) {
            return .exact(exact)
        }
        if let fallback = profiles.first(where: {
            $0.isDefault
                && $0.monitorCount == fingerprints.count
        }) {
            return .countDefault(fallback)
        }
        return .none
    }

    /// The count's default profile (alphabetically first when
    /// hand-edited duplicates exist).
    public func defaultProfile(count: Int) -> Profile? {
        allProfiles().first {
            $0.isDefault && $0.monitorCount == count
        }
    }

    /// Screen counts where several profiles claim the default
    /// flag (hand-edited) — surfaces a GUI warning badge.
    public func duplicateDefaultCounts() -> [Int] {
        var counts: [Int: Int] = [:]
        for profile in allProfiles() where profile.isDefault {
            counts[profile.monitorCount, default: 0] += 1
        }
        return counts.filter { $0.value > 1 }.keys.sorted()
    }
}
