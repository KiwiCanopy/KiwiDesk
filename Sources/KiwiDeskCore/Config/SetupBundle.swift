import Foundation

/// Everything a KiwiDesk backup carries as one JSON document
/// (#606): `gui.json`, profiles, and the saved palette library.
/// The contents are an ALLOW-LIST, never a directory sweep —
/// `init.lua` stays behind (user-authored code a backup must not
/// claim), as do the arrangement snapshots (this Mac's session)
/// and the socket/lock (runtime). Add an entry only for a path
/// something actually creates.
public struct SetupBundle: Codable, Sendable, Equatable {
    /// Supported bundle format version. Not a compatibility shim —
    /// a refusal signal: this is the one artifact that legitimately
    /// outlives the build, and `JSONDecoder` is lenient, so a
    /// future-format bundle would decode "successfully" with data
    /// silently dropped. One integer turns that into a refusal.
    /// 2 = the bar-content rename (owner ruling 2026-08-19);
    /// 3 = the scroll-duration rename, on `[Profile]` alone
    /// (#1020 — `GuiConfig.currentFormat` carries why its half
    /// deliberately did not move).
    public static let currentFormat = 3

    public let format: Int

    /// Top-level key `ConfigMigration.targetFormat` routes a bundle on
    /// (`ConfigMigrationTests.shapeMarkersMatchEncodedShapes`).
    static let shapeMarker = "writtenBy"

    /// Informational version string of the writing KiwiDesk build.
    public let writtenBy: String
    /// GUI-managed settings, or nil. Nil has TWO causes and only
    /// one is benign — no sidecar at all, or one that would not
    /// decode — so `exportSetup` checks `guiConfigStore.exists`
    /// rather than trusting the nil (code-reviewer 2026-08-17): a
    /// backup is the artifact a user makes because they are about
    /// to need it.
    public let config: GuiConfig?
    public let profiles: [Profile]
    public let palettes: [ColorPalette]

    public init(
        format: Int = SetupBundle.currentFormat,
        writtenBy: String,
        config: GuiConfig?,
        profiles: [Profile],
        palettes: [ColorPalette]
    ) {
        self.format = format
        self.writtenBy = writtenBy
        self.config = config
        self.profiles = profiles
        self.palettes = palettes
    }

    /// Whether this build can read the bundle format.
    public var isReadable: Bool {
        format <= SetupBundle.currentFormat
    }

    /// Whether this bundle replaces `artifact` — and the
    /// distinction is ABSENT, not empty: the export always writes
    /// both arrays, so `[]` means the source Mac had none, and
    /// replacing with none is what "a restore replaces; it never
    /// merges" promises. Only `config == nil` is a true absence
    /// (architect-reviewer 2026-08-17).
    public func replaces(_ artifact: ConfigArtifact) -> Bool {
        switch artifact {
        case .guiConfig: return config != nil
        case .profiles, .palettes: return true
        }
    }

    /// True when bundle carries no settings, profiles, or palettes.
    public var isEmpty: Bool {
        config == nil && profiles.isEmpty && palettes.isEmpty
    }
}

/// Structural outcome of a backup restore
/// (#96, architect-reviewer 2026-08-17).
public struct RestoreOutcome: Equatable, Sendable {
    /// Profiles that could not be written.
    public let skippedProfiles: [String]
    /// Palettes dropped for shadowing built-ins or duplicate names.
    public let refusedPalettes: Int

    public var isClean: Bool {
        skippedProfiles.isEmpty && refusedPalettes == 0
    }
}

/// Structured error cases for backup read/write operations (#96).
public enum SetupBundleError: Error, Equatable, Sendable {
    /// The file could not be read or is not JSON.
    case unreadable
    /// Valid JSON that is not a KiwiDesk backup.
    case notABackup
    /// Written by a newer KiwiDesk format.
    case newerFormat(found: Int, supported: Int)
    /// A backup that contains no restoreable items.
    case empty
    /// Writing failed, naming the target file.
    case couldNotWrite(name: String)
    /// Existing `gui.json` failed to decode during export.
    case unreadableSettings
    /// Existing `palettes.json` failed to decode during export (#945).
    case unreadablePalettes
    /// Target Mac is Lua-owned, so the settings half could not
    /// apply: `loadConfig` never reads the restored rules and
    /// keybindings there while the profile-scoped half applies
    /// anyway — a half-landed restore, and reporting success for
    /// it is the failure this case exists to prevent.
    case luaOwnsThisMac
}
