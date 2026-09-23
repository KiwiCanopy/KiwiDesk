import Foundation

/// A monitor combination belongs to one profile: the one most
/// recently stored or loaded with it (#1530).
extension ProfileManager {
    /// Strips the combination `monitors` from every OTHER profile
    /// of that screen count, so `name` alone holds it. Returns the
    /// profiles that lost it, sorted.
    ///
    /// Non-adopting writes only. A default left dormant — never
    /// auto-matched — hands its flag to `name`, so the count keeps
    /// a default that can load. The caller writes `name`'s own set
    /// first; boot never calls this (two hand-edited owners
    /// resolve as `match` always has).
    @discardableResult
    func claim(
        _ monitors: [String],
        for name: String
    ) throws -> [String] {
        var released: [String] = []
        var orphanedDefault = false
        for var other in allProfiles()
        where other.name != name
            && other.monitorCount == monitors.count
        {
            guard other.release(monitors) else { continue }
            if other.isDormant, other.isDefault {
                other.isDefault = false
                orphanedDefault = true
            }
            try write(other)
            released.append(other.name)
        }
        if orphanedDefault,
            defaultProfile(count: monitors.count) == nil,
            var claimant = try? read(name: name)
        {
            claimant.isDefault = true
            try write(claimant)
        }
        return released.sorted()
    }

    /// Drops the flag from a dormant profile of `count` — a hand
    /// edit's leftover — when another is made that count's
    /// default, so the count never shows two (#1530).
    func clearDormantDefaults(count: Int) throws {
        for var stale in allProfiles()
        where stale.monitorCount == count
            && stale.isDormant && stale.isDefault
        {
            stale.isDefault = false
            try write(stale)
        }
    }
}
