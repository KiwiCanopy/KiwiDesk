import Foundation

/// Persists profiles and picks the right one when the monitor
/// setup changes.
///
/// Selection algorithm (05_GUI_Concept §1):
/// 1. Direct match: same monitor fingerprints.
/// 2. Count fallback: same number of monitors.
/// 3. Default: none — the caller keeps a transient state and
///    marks the profile dirty.
@MainActor
public final class ProfileManager {
    public private(set) var currentName: String?
    /// True when the live state diverged from the saved
    /// profile (e.g. after a monitor change).
    public private(set) var isDirty = false

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    // MARK: - Persistence

    public func list() -> [String] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                atPath: directory.path
            )) ?? []
        return
            contents
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
            .sorted()
    }

    public func save(_ profile: Profile) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        // Human-readable timestamps in the profile files.
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(profile).write(
            to: url(for: profile.name),
            options: .atomic
        )
        currentName = profile.name
        isDirty = false
    }

    public func load(name: String) throws -> Profile {
        let profile = try read(name: name)
        currentName = profile.name
        isDirty = false
        return profile
    }

    /// Reads a profile without touching current/dirty state.
    private func read(name: String) throws -> Profile {
        let data = try Data(contentsOf: url(for: name))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            Profile.self,
            from: data
        )
    }

    // MARK: - Monitor matching

    /// Finds the best profile for a monitor setup. Does not
    /// change the current profile — callers decide whether to
    /// apply the match.
    public func match(
        fingerprints: [String],
        count: Int
    ) -> Profile? {
        let profiles = list().compactMap { name in
            try? read(name: name)
        }
        let wanted = Set(fingerprints)
        if let direct = profiles.first(where: {
            Set($0.fingerprints) == wanted
        }) {
            return direct
        }
        return profiles.first {
            $0.monitorCount == count
        }
    }

    /// Marks the live state as diverged (transient state).
    public func markDirty() {
        isDirty = true
    }

    /// Records that a matched profile is now active.
    public func adopt(_ profile: Profile) {
        currentName = profile.name
        isDirty = false
    }

    private func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }
}
