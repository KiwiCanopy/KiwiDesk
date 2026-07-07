import Foundation

/// The outcome of matching the live monitors against the saved
/// profiles (#36). Either an exact set matches (adopt clean),
/// the count's default user profile applies (load dirty), or
/// nothing does and the caller composes the built-in Standard
/// (#53). No near-match adaptation.
public enum ProfileMatch: Equatable {
    case exact(Profile)
    case countDefault(Profile)
    case none
}

/// Thrown for profile names that cannot become file names.
public enum ProfileError: Error, CustomStringConvertible {
    case invalidName(String)

    public var description: String {
        switch self {
        case .invalidName(let name):
            return "invalid profile name: '\(name)'"
        }
    }
}

/// Persists profiles and picks the right one when the monitor
/// setup changes.
@MainActor
public final class ProfileManager {
    public private(set) var currentName: String?
    /// The built-in Standard currently resolving (no saved
    /// profile covers the live screen count), if any.
    public private(set) var currentStandard: String?
    /// True when the live state diverged from the saved
    /// profile (e.g. after a monitor change).
    public private(set) var isDirty = false

    private let directory: URL

    /// Invalid profile files reported while listing (#31).
    public var onLog: @MainActor (String) -> Void = { _ in }

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
            // read() rejects invalid names, so listing them
            // (e.g. a hand-placed dot-file) would only log
            // "invalid" on every allProfiles() pass.
            .filter(Self.isValidName)
            .sorted()
    }

    /// Every readable profile, sorted by name. Unreadable files
    /// are skipped (and logged), never fatal.
    public func allProfiles() -> [Profile] {
        list().compactMap { name in
            do {
                return try read(name: name)
            } catch {
                onLog(
                    "profile '\(name)' is invalid: \(error)"
                )
                return nil
            }
        }
    }

    /// Saves the profile; the first profile of its screen count
    /// is auto-flagged as that count's default.
    func save(_ profile: Profile) throws {
        var profile = profile
        if !profile.isDefault,
            defaultProfile(count: profile.monitorCount) == nil
        {
            profile.isDefault = true
        }
        try write(profile)
        currentName = profile.name
        currentStandard = nil
        isDirty = false
    }

    func load(name: String) throws -> Profile {
        let profile = try read(name: name)
        currentName = profile.name
        currentStandard = nil
        isDirty = false
        return profile
    }

    /// Deletes a profile. A count left without a default gets
    /// the alphabetically-first remaining profile flagged; the
    /// last profile of a count simply reverts the count to the
    /// built-in Standard. A count that still has a default
    /// (hand-edited duplicates) is left alone. When the deleted
    /// file was unreadable its count is unknown, so every
    /// orphaned count is repaired.
    func delete(name: String) throws {
        let deleted = try? read(name: name)
        try FileManager.default.removeItem(
            at: url(for: validated(name))
        )
        if currentName == name {
            currentName = nil
            isDirty = true
        }
        let counts =
            deleted.map { [$0.monitorCount] }
            ?? Array(Set(allProfiles().map(\.monitorCount)))
        for count in counts
        where defaultProfile(count: count) == nil {
            if var heir = allProfiles().first(where: {
                $0.monitorCount == count
            }) {
                heir.isDefault = true
                try write(heir)
            }
        }
    }

    /// Re-designates a count's default: flags `name`, clears
    /// the flag on every other profile of the same count.
    func setDefault(name: String) throws {
        var chosen = try read(name: name)
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

    /// `base`, or `base_1`, `base_2`, … up to the next free
    /// name — repeated preset Applies accumulate copies (#53).
    public func freeName(base: String) -> String {
        let taken = Set(list())
        guard taken.contains(base) else { return base }
        var suffix = 1
        while taken.contains("\(base)_\(suffix)") {
            suffix += 1
        }
        return "\(base)_\(suffix)"
    }

    /// Reads a profile without touching current/dirty state.
    public func read(name: String) throws -> Profile {
        let data = try Data(
            contentsOf: url(for: validated(name))
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: data)
    }

    /// Names become file names inside the profiles directory:
    /// path separators, traversal, hidden-file prefixes, and
    /// blank names are rejected at this boundary — every caller
    /// (CLI, Lua, IPC, GUI) funnels through here.
    public static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return !trimmed.isEmpty
            && !name.contains("/")
            && !name.contains("\0")
            && !name.hasPrefix(".")
    }

    /// The name, or `ProfileError.invalidName`.
    private func validated(
        _ name: String
    ) throws -> String {
        guard Self.isValidName(name) else {
            throw ProfileError.invalidName(name)
        }
        return name
    }

    // MARK: - Monitor matching

    /// Finds the profile for a live monitor set: exact stored
    /// set (sorted-array comparison) → the count's default user
    /// profile → none (caller composes the Standard). Ties
    /// resolve alphabetically (profiles come pre-sorted).
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

    // MARK: - State

    /// Marks the live state as diverged (transient state).
    func markDirty() {
        isDirty = true
    }

    /// Records that a matched profile is now active.
    func adopt(_ profile: Profile) {
        currentName = profile.name
        currentStandard = nil
        isDirty = false
    }

    /// Records that a built-in Standard is resolving; always a
    /// dirty (transient) state until the user saves.
    func adoptStandard(named name: String) {
        currentName = nil
        currentStandard = name
        isDirty = true
    }

    /// The non-adopting write: persists the JSON only, touching
    /// no `current`/`dirty` state. `save()` layers adoption on
    /// top; an edit-without-activating path (`overwriteProfile`)
    /// writes through here directly so editing a stored profile
    /// never switches the live layout (#18).
    func write(_ profile: Profile) throws {
        let name = try validated(profile.name)
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
            to: url(for: name),
            options: .atomic
        )
    }

    private func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }
}
