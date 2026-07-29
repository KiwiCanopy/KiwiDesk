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

/// Thrown for profile names that cannot become file names, and
/// for renames that would clobber an existing profile.
public enum ProfileError: Error, CustomStringConvertible {
    case invalidName(String)
    case nameTaken(String)

    public var description: String {
        switch self {
        case .invalidName(let name):
            return "invalid profile name: '\(name)'"
        case .nameTaken(let name):
            return "a profile named '\(name)' already exists"
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

    let directory: URL

    /// Invalid profile files reported while listing (#31).
    public var onLog: @MainActor (String) -> Void = CoreLog.write

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

    /// Every profile file with its decode outcome, in one disk
    /// pass: a readable `Profile`, or the error that makes it
    /// broken. The single source `allProfiles`, `brokenNames`,
    /// and the config-issue scan all derive from (#246).
    func scan() -> [(name: String, result: Result<Profile, Error>)] {
        list().map { name in
            (name, Result { try read(name: name) })
        }
    }

    /// Every readable profile, sorted by name. Unreadable files
    /// are skipped (and logged), never fatal.
    public func allProfiles() -> [Profile] {
        scan().compactMap { name, result in
            switch result {
            case .success(let profile):
                return profile
            case .failure(let error):
                onLog("profile '\(name)' is invalid: \(error)")
                return nil
            }
        }
    }

    /// Names whose JSON won't decode — greyed out, never hidden,
    /// so a broken profile stays deletable wherever listed
    /// (#246, #171).
    public func brokenNames() -> [String] {
        scan().compactMap { name, result in
            if case .failure = result { return name }
            return nil
        }
    }

    /// On-disk path of a profile file, for Reveal in Finder
    /// (#246). Validated like every other path; the file may or
    /// may not exist.
    public func fileURL(name: String) throws -> URL {
        url(for: try validated(name))
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

    /// Renames a stored profile via an atomic file move, then
    /// rewrites the JSON's own name field. NOT write-new-then-
    /// remove-old: on a case-insensitive volume (default APFS)
    /// a case-only rename ("work" → "Work") resolves both
    /// names to ONE file, and the remove leg would delete the
    /// just-renamed profile. `moveItem` handles the case
    /// change in place; any other existing destination is
    /// rejected, never clobbered (`fileExists` matches case-
    /// insensitively there, so "a" → "b" beside "B.json" is
    /// caught too). Same-name is a no-op. Carries the adopted
    /// `currentName` along. The `KiwiCore` facade chases
    /// external references (native-Space bindings). Accepted
    /// non-atomicity: if the name-field rewrite after the
    /// move fails, the file is at the new name with the old
    /// name inside — a tiny window (same directory, just
    /// proven writable), traded for the case-safety above.
    func rename(from old: String, to new: String) throws {
        guard old != new else { return }
        var profile = try read(name: old)
        let source = url(for: try validated(old))
        let destination = url(for: try validated(new))
        let files = FileManager.default
        let caseOnly =
            old.caseInsensitiveCompare(new) == .orderedSame
        if !caseOnly,
            files.fileExists(atPath: destination.path)
        {
            throw ProfileError.nameTaken(new)
        }
        try files.moveItem(at: source, to: destination)
        profile.name = new
        try write(profile)
        if currentName == old { currentName = new }
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
    /// Case-insensitive, matching the rename path: profile
    /// files live on case-insensitive APFS, so "My Setup"
    /// passing a case-sensitive check would silently overwrite
    /// "my setup.json" (QA round 2 review).
    public func freeName(base: String) -> String {
        let taken = Set(list().map { $0.lowercased() })
        guard taken.contains(base.lowercased()) else {
            return base
        }
        var suffix = 1
        while taken.contains(
            "\(base)_\(suffix)".lowercased()
        ) {
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

    /// Back to the nothing-adopted state — for Reset All
    /// Settings (#634), after the profile files were trashed:
    /// a `currentName` pointing at a deleted file would make
    /// every re-apply path report a read failure.
    func resetAdoption() {
        currentName = nil
        currentStandard = nil
        isDirty = false
    }

    /// The non-adopting write: persists the JSON only, touching
    /// no `current`/`dirty` state. `save()` layers adoption on
    /// top; the edit-without-activating paths
    /// (`overwriteProfile`, `copyProfile` #82) write through
    /// here directly so editing a stored profile never
    /// switches the live layout (#18).
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
