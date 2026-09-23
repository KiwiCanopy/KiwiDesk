import Foundation

/// The one-time settle of monitor sets that several profiles held
/// before #1530 made a set one profile's.
extension ProfileManager {
    /// Hands every doubly-held set to the profile `match` loads for
    /// it today — the alphabetically first holder — and strips it
    /// from the rest through `claim`, so nothing loads differently;
    /// only entries that could never win go. Returns one line per
    /// settled set, for the log.
    ///
    /// Run at a crossing, never per boot: a duplicate hand-edited
    /// in later resolves as `match` always has (the #1530 ruling).
    @discardableResult
    func settleSharedSets() throws -> [String] {
        var settled: Set<[String]> = []
        var lines: [String] = []
        for holder in allProfiles() {
            for set in holder.monitorSets
            where settled.insert(set.monitors).inserted {
                let released = try claim(set.monitors, for: holder.name)
                guard !released.isEmpty else { continue }
                lines.append(
                    "profiles: \(set.monitors.joined(separator: " + "))"
                        + " stays with '\(holder.name)', taken from "
                        + released.map { "'\($0)'" }
                        .joined(separator: ", ")
                )
            }
        }
        return lines
    }

    /// Whether a profile file on disk predates the one-owner
    /// format — read raw, since `read` stamps the file it reads.
    func hasFilesBeforeOneOwnerFormat() -> Bool {
        list().contains { name in
            guard
                let data = try? Data(contentsOf: fileURL(name: name)),
                let root = try? JSONSerialization.jsonObject(
                    with: data
                ) as? [String: Any]
            else { return false }
            return (root["format"] as? Int ?? 0) < Self.oneOwnerFormat
        }
    }

    /// The profile format that made a set one profile's (#1530).
    static let oneOwnerFormat = 6
}
