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
    case dormantDefault(String)

    public var description: String {
        switch self {
        case .invalidName(let name):
            return "invalid profile name: '\(name)'"
        case .nameTaken(let name):
            return "a profile named '\(name)' already exists"
        case .dormantDefault(let name):
            return
                "'\(name)' holds no screen setup, so it cannot be "
                + "a screen count's default; load it first"
        }
    }
}

/// Persists profiles and selects matching configurations for monitor setups.
@MainActor
public final class ProfileManager {
    /// The active profile, and the one authority for whose
    /// arrangement the live Spaces represent (#1249).
    ///
    /// Never non-nil beside `currentStandard`: every writer that
    /// sets one clears the other, which is what lets a caller
    /// holding the name already treat `markClean()` as a whole
    /// re-adopt.
    public var currentName: String? { active?.name }
    /// The live profile's screen count, from adoption state
    /// (#1436, #1245).
    public var currentMonitorCount: Int? { active?.monitorCount }

    /// The active profile as one value — what `currentName` reads
    /// from, and what a Desktop switch asks for the declared
    /// Spaces instead of the disk (#1245).
    private(set) var active: ActiveProfile?
    /// Nonzero while an apply or a config load moves what is live
    /// and what is declared (#1790): a temporary Space is judged
    /// against the adoption state, which is the OUTGOING one until
    /// the apply's last line, so nothing is retired meanwhile.
    var arrangementInFlight = 0
    /// The live profile's saved layout modes as last adopted or
    /// written (#1245, #1518), tagged so a stale copy never
    /// answers for another profile.
    private var savedModesRecord:
        (profile: String, modes: [SpaceID: LayoutMode])?

    /// The live profile's saved layout modes; nil while none is
    /// live.
    var liveSpaceModes: [SpaceID: LayoutMode]? {
        guard let name = currentName, let record = savedModesRecord,
            record.profile == name
        else { return nil }
        return record.modes
    }
    /// Built-in Standard currently resolving (nil if covered by saved
    /// profile).
    public var currentStandard: String? { standard?.name }
    /// The live Standard's starter title, nil for a workflow (#1662).
    public var currentStandardTitle: StarterTitle? { standard?.title }
    /// Whether the active profile is the starter setup.
    var activeIsStarterSetup: Bool { active?.isStarterSetup ?? false }
    /// The resolving Standard as one value, `currentStandard`'s
    /// source (#1509).
    private(set) var standard: ActiveStandard?
    /// True when live state diverged from saved profile.
    public private(set) var isDirty = false

    let directory: URL

    /// Invalid profile files reported while listing (#31).
    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// Fired after a profile write from outside Settings lands —
    /// Keep's layouts, or `save_profile`'s whole-live snapshot —
    /// so an open Settings draft's baseline follows the file for
    /// exactly what was written. On the WRITE rather than on
    /// either caller (#1179, #1790).
    public var onCapturedLive: @MainActor (String, CapturedWrite) -> Void =
        { _, _ in }

    /// A profile predating the one-owner format was on disk when
    /// this manager was made, and no settle has run since (#1530).
    public internal(set) var owesSetSettle: Bool

    /// Where a migrated rewrite keeps the original (#1880), set by
    /// the core that owns the config directory; nil keeps none.
    var migrationBackups: URL?

    public init(directory: URL) {
        self.directory = directory
        owesSetSettle = Self.owesSettle(in: directory)
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
            try clearDormantDefaults(count: profile.monitorCount)
        }
        try write(profile)
        adopt(profile)
        standard = nil
        isDirty = false
    }

    /// Deletes a profile, repairing orphaned count defaults if needed.
    func delete(name: String) throws {
        let deleted = try? read(name: name)
        try FileManager.default.removeItem(
            at: url(for: validated(name))
        )
        if currentName == name {
            active = nil
            isDirty = true
        }
        let counts =
            deleted.map { [$0.monitorCount] }
            ?? Array(Set(allProfiles().map(\.monitorCount)))
        for count in counts
        where defaultProfile(count: count) == nil {
            if var heir = allProfiles().first(where: {
                $0.monitorCount == count && !$0.isDormant
            }) {
                heir.isDefault = true
                try write(heir)
                try clearDormantDefaults(count: count)
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
        if currentName == old {
            active = active?.renamed(to: new)
            savedModesRecord = (new, profile.spaceModes)
        }
    }

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

    /// Reads a profile with atomic best-effort `ConfigMigration` rewrite.
    public func read(name: String) throws -> Profile {
        let file = url(for: try validated(name))
        var data = try Data(contentsOf: file)
        // Raw bytes, to preserve unknown keys.
        data = MigrationBackup.migrateInPlace(
            data,
            at: file,
            backups: migrationBackups
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: data)
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

    /// Marks the live state as matching the file — `markDirty`'s
    /// counterpart, for a caller that ran no apply, or one whose
    /// verdict differs from the apply's (#1249).
    func markClean() {
        isDirty = false
    }

    /// Records that `profile` is the layout now live, and whether
    /// it describes the hardware it landed on (#36).
    ///
    /// `apply(profile:)`'s and no one else's — profiles.md ▸
    /// "Whose arrangement is live" (#1249).
    func becameLive(_ profile: Profile, fits: Bool) {
        adopt(profile)
        standard = nil
        isDirty = !fits
    }

    /// Records that a built-in Standard is live — `apply(composed:)`'s
    /// door, and `becameLive`'s mirror: the name and the Spaces the
    /// apply composed as ONE value, filed by the apply itself so no
    /// caller can forget them (#1509, #1246). A Standard is never a
    /// saved profile, so the state is dirty.
    func standardIsLive(_ standard: ActiveStandard) {
        active = nil
        self.standard = standard
        isDirty = true
    }

    /// The live-write door's write of the live profile (#1790): the
    /// declared Spaces follow the file, since live moved with it —
    /// a Space added is no longer temporary, one removed is gone.
    /// Any other write leaves them to the next apply (#1245), which
    /// judges what the file dropped against what was declared.
    /// The name and fit stay as they were.
    func redeclare(_ profile: Profile) {
        guard profile.name == currentName else { return }
        adopt(profile)
    }

    /// The one place both adoption records are set.
    private func adopt(_ profile: Profile) {
        active = ActiveProfile(profile)
        savedModesRecord = (profile.name, profile.spaceModes)
    }

    /// Resets adoption state for Reset All Settings (#634).
    func resetAdoption() {
        active = nil
        standard = nil
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
        if profile.name == currentName {
            savedModesRecord = (profile.name, profile.spaceModes)
        }
    }

    private func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }
}
