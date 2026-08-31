import Foundation

/// Outcome of matching live monitors against saved profiles (#36, #53).
public enum ProfileMatch: Equatable {
    case exact(Profile)
    case countDefault(Profile)
    case none
}

/// Thrown for invalid profile names or name collisions.
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

/// Persists profiles and selects matching configurations for monitor setups.
@MainActor
public final class ProfileManager {
    public private(set) var currentName: String?
    /// Built-in Standard currently resolving (nil if covered by saved
    /// profile).
    public private(set) var currentStandard: String?
    /// True when live state diverged from saved profile.
    public private(set) var isDirty = false

    let directory: URL

    /// Invalid profile files reported while listing (#31).
    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// Fired after a CAPTURE-LIVE profile write lands — the
    /// quick menu's Keep and the `save_profile` command alike,
    /// so an open Settings draft's baseline follows the file.
    /// On the WRITE rather than on either caller (#1179).
    public var onCapturedLive: @MainActor (String) -> Void = { _ in }

    public init(directory: URL) {
        self.directory = directory
    }

    public func list() -> [String] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                atPath: directory.path
            )) ?? []
        return
            contents
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
            .filter(Self.isValidName)
            .sorted()
    }

    /// Every profile file with its decode outcome (#246).
    func scan() -> [(name: String, result: Result<Profile, Error>)] {
        list().map { name in
            (name, Result { try read(name: name) })
        }
    }

    /// Every readable profile, sorted by name (unreadable files
    /// skipped/logged).
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

    /// On-disk path of a profile file (#246).
    public func fileURL(name: String) throws -> URL {
        url(for: try validated(name))
    }

    /// Saves the profile; auto-flags as count's default if first for count.
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

    /// Deletes a profile, repairing orphaned count defaults if needed.
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

    /// Renames a stored profile via an atomic move — NOT
    /// write-new-then-remove-old: on case-insensitive APFS a
    /// case-only rename resolves both names to ONE file, and the
    /// remove leg would delete the just-renamed profile. Accepted
    /// non-atomicity: if the name-field rewrite after the move
    /// fails, the file sits at the new name with the old name
    /// inside — a tiny window, traded for the case safety.
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

    /// Re-designates a count's default profile.
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

    /// Next available case-insensitive name suffix (`base`, `base_1`, ...)
    /// (#53, APFS case safety).
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

    /// Reads a profile with atomic best-effort `ConfigMigration` rewrite.
    public func read(name: String) throws -> Profile {
        let file = url(for: try validated(name))
        var data = try Data(contentsOf: file)
        if let migrated = ConfigMigration.migrated(data) {
            data = migrated
            // Writes migrated raw bytes directly to preserve unknown keys.
            try? migrated.write(to: file, options: .atomic)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: data)
    }

    /// Validates profile filename boundaries (no slashes, nulls, dot-files).
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

    /// Records that a built-in Standard is resolving (dirty state).
    func adoptStandard(named name: String) {
        currentName = nil
        currentStandard = name
        isDirty = true
    }

    /// Resets adoption state for Reset All Settings (#634).
    func resetAdoption() {
        currentName = nil
        currentStandard = nil
        isDirty = false
    }

    /// Non-adopting write for background profile editing (#18, #82).
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
        // Not the store's only writer since `read(name:)` gained
        // its migration write-back — that one writes raw bytes on
        // purpose, because this encoder can only write fields
        // this build knows.
        try encoder.encode(profile).write(
            to: url(for: name),
            options: .atomic
        )
    }

    private func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }
}
