import Foundation

extension ProfileManager {
    /// Re-designates a count's default profile. A dormant profile
    /// cannot load as a fallback, so it is refused (#1530).
    func setDefault(name: String) throws {
        var chosen = try read(name: name)
        guard !chosen.isDormant else {
            throw ProfileError.dormantDefault(name)
        }
        chosen.isDefault = true
        try write(chosen)
        for var other in allProfiles()
        where other.name != name
            && other.monitorCount == chosen.monitorCount
            && other.isDefault
        {
            other.isDefault = false
            try write(other)
        }
    }
}
