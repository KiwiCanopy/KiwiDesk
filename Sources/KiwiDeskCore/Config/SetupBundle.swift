import Foundation

/// Everything a KiwiDesk backup carries, as one document (#606).
///
/// **One JSON file, not a zip.** Every piece that travels is
/// already JSON, so an archive would add a packing step, a
/// partial-extract failure mode and a temporary directory to buy
/// nothing: this decodes and validates whole before anything on
/// the destination Mac is touched.
///
/// **The contents are an allow-list, never a directory sweep.**
/// `~/.config/KiwiDesk` also holds a socket, a lock file, the
/// remembered window arrangement (`.state_snapshot`) and whatever
/// `.bak-*` directories a past reset left behind. None of that
/// describes how the user likes their desk, and the snapshot is
/// actively machine-specific. What travels:
///
/// **Carried:** `gui.json`'s contents, every profile, and the
/// saved palette library.
///
/// **Left behind, each for its own reason:** `init.lua`, because
/// it is user-authored code and a backup that quietly restored it
/// would claim ownership of a file KiwiDesk deliberately does not
/// manage; `.state_snapshot`, because the remembered arrangement
/// is this Mac's session rather than a setting; and the socket,
/// the lock file and any `*.bak-*` left by a past reset, which are
/// runtime and rubble.
///
/// Palettes are here because they do **not** ride inside
/// `gui.json`: applying a palette writes its colours into the
/// settings, so the current *look* travels with the config while
/// the user's saved *library* lives in `palettes.json` and would
/// otherwise be left behind — the one thing a person moving Macs
/// would most notice missing.
public struct SetupBundle: Codable, Sendable, Equatable {
    /// The format this build writes and is willing to read.
    ///
    /// **Not a compatibility shim**, which AGENTS.md §5 rules out
    /// pre-release. It is a refusal signal, and it earns its place
    /// because this is the one artifact that legitimately outlives
    /// the running build: it is written to a file, carried to
    /// another Mac and read back by whatever version is installed
    /// there. `JSONDecoder` is lenient, so a bundle from a future
    /// format would decode "successfully" with unknown fields
    /// dropped — a restore that reports success having silently
    /// lost data. One integer turns that into a refusal.
    public static let currentFormat = 1

    public let format: Int
    /// The version that wrote it — informational, for a human
    /// looking at a file they were mailed. Nothing branches on it;
    /// `format` is the only compatibility question.
    public let writtenBy: String
    /// The GUI-managed settings. Absent when the user's config is
    /// Lua-owned and no sidecar exists, which is a legitimate
    /// backup — their profiles and palettes still travel.
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

    /// Whether this build can read it.
    public var isReadable: Bool {
        format <= SetupBundle.currentFormat
    }

    /// True when the bundle would restore nothing at all — no
    /// settings, no profiles, no palettes.
    ///
    /// Exporting one is legitimate (a fresh install has little to
    /// say), but restoring one is almost certainly a mistake the
    /// user should be told about rather than a wipe they asked
    /// for.
    public var isEmpty: Bool {
        config == nil && profiles.isEmpty && palettes.isEmpty
    }
}

/// What can go wrong reading or writing a backup.
///
/// Structure, never a sentence: Core names the condition and the
/// GUI renders the copy at its own boundary (#96,
/// `core-boundaries.md`). A pre-rendered English string here would
/// be invisible to `scripts/extract-keys` and untranslatable in
/// every catalog.
public enum SetupBundleError: Error, Equatable, Sendable {
    /// The file could not be read at all — gone, unreadable, or
    /// not JSON.
    case unreadable
    /// Valid JSON that is not a KiwiDesk backup.
    case notABackup
    /// Written by a newer KiwiDesk than this one.
    case newerFormat(found: Int, supported: Int)
    /// A backup that would restore nothing.
    case empty
    /// Writing failed, naming the file that did not land.
    case couldNotWrite(name: String)
}
