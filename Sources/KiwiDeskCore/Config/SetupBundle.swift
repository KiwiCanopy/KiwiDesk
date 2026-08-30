import Foundation

/// Everything a KiwiDesk backup carries as one JSON document (#606).
/// Carries `gui.json`, profiles, and saved palette library (`palettes.json`).
public struct SetupBundle: Codable, Sendable, Equatable {
    /// Supported bundle format version (format 2: bar-content rename, owner
    /// ruling 2026-08-19; format 3: scroll-duration rename on Profile, #1020).
    public static let currentFormat = 3

    public let format: Int

    /// Top-level key `ConfigMigration.targetFormat` routes a bundle on
    /// (`ConfigMigrationTests.shapeMarkersMatchEncodedShapes`).
    static let shapeMarker = "writtenBy"

    /// Informational version string of the writing KiwiDesk build.
    public let writtenBy: String
    /// GUI-managed settings, or nil if unmanaged (code-reviewer 2026-08-17).
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

    /// Whether this bundle replaces `artifact`
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
    /// Target Mac is Lua-managed so GUI settings cannot apply.
    case luaOwnsThisMac
}
