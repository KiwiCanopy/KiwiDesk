import Foundation

/// The one-time settle of monitor sets that several profiles held
/// before #1530 made a set one profile's.
extension ProfileManager {
    /// Hands every doubly-held set to the profile `match` loads for
    /// it today — the alphabetically first holder — and strips it
    /// from the rest through `claim`, so every exact match loads as
    /// before. Where a stripped holder was its count's default, the
    /// flag moves with the set, which the log says. Returns one line
    /// per change, for the log.
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
                let count = set.monitors.count
                let fallback = defaultProfile(count: count)?.name
                let released = try claim(set.monitors, for: holder.name)
                guard !released.isEmpty else { continue }
                lines.append(
                    "profiles: \(set.monitors.joined(separator: " + "))"
                        + " stays with '\(holder.name)', taken from "
                        + released.map { "'\($0)'" }
                        .joined(separator: ", ")
                )
                let now = defaultProfile(count: count)?.name
                if now != fallback, let now {
                    lines.append(
                        "profiles: '\(now)' is now the default for "
                            + "\(count) screen(s)"
                    )
                }
            }
        }
        owesSetSettle = false
        return lines
    }

    /// Whether `directory` holds a profile written before the
    /// one-owner format. Decided ONCE, when the manager is made:
    /// any later read stamps the file it reads (`read`), so a
    /// Settings refresh before the first config load would
    /// otherwise close the crossing unsettled. Only a file that IS
    /// a profile counts — a stray or broken `.json` is stamped with
    /// another shape's format and would hold the crossing open
    /// forever. Reads, never writes.
    static func owesSettle(in directory: URL) -> Bool {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files.contains { file in
            guard file.pathExtension == "json",
                let data = try? Data(contentsOf: file),
                let root = try? JSONSerialization.jsonObject(
                    with: data
                ) as? [String: Any],
                (root["format"] as? Int ?? 0) < oneOwnerFormat
            else { return false }
            let current = ConfigMigration.migrated(data) ?? data
            return (try? decoder.decode(Profile.self, from: current))
                != nil
        }
    }

    /// The profile format that made a set one profile's (#1530) —
    /// history, not `Profile.currentFormat`, which moves on.
    static let oneOwnerFormat = 6
}
