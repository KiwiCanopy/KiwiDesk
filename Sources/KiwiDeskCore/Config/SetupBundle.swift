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
/// `~/.config/KiwiDesk` also holds the IPC socket, the instance
/// lock (`SingleInstanceLock`) and the remembered window
/// arrangement (`CrashRecovery`'s `.state_snapshot` and its
/// session file). None of that describes how the user likes their
/// desk, and the snapshots are actively machine-specific. What
/// travels:
///
/// **Carried:** `gui.json`'s contents, every profile, and the
/// saved palette library.
///
/// **Left behind, each for its own reason:** `init.lua`, because
/// it is user-authored code and a backup that quietly restored it
/// would claim ownership of a file KiwiDesk deliberately does not
/// manage; the arrangement snapshots, because a remembered
/// arrangement is this Mac's session rather than a setting; and
/// the socket and the lock file, which are runtime.
///
/// An earlier draft of this list also named `.bak-*` directories
/// "a past reset left behind". Nothing in the tree writes one —
/// `resetAllSettings` trashes, it does not copy aside — so the
/// entry described a file that has never existed. Add an entry
/// here only for a path something actually creates.
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
    /// The GUI-managed settings, or nil.
    ///
    /// Nil has **two** causes and only one of them is benign:
    /// there is no sidecar (a Lua-owned config, a legitimate
    /// backup whose profiles and palettes still travel), or there
    /// is one and it would not decode. `GuiConfigStore.load`
    /// answers nil to both, so an export from a Mac with a corrupt
    /// `gui.json` silently produces a settings-less backup and
    /// reports success (`code-reviewer`, 2026-08-17).
    ///
    /// `exportSetup` therefore checks `guiConfigStore.exists`
    /// rather than trusting the nil, and refuses the second case:
    /// a backup is the one artifact a user makes precisely because
    /// they are about to need it.
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
    /// This Mac has a `gui.json` that will not decode, so an
    /// export would silently omit every setting.
    ///
    /// Distinguished from "no sidecar at all" by
    /// `GuiConfigStore.exists`, because the two look identical
    /// through `load()` and only one of them is a backup worth
    /// making.
    case unreadableSettings
    /// The backup carries settings, but this Mac's `init.lua`
    /// owns the configuration, so the settings half could not be
    /// applied.
    ///
    /// `isGuiManaged` is the one ownership predicate
    /// (`profiles.md`), and on a Lua-owned destination
    /// `loadConfig` takes the `applyConfigGlobals` branch: the
    /// restored rules and keybindings in the written `gui.json`
    /// are never read, while the profile-scoped half applies
    /// anyway. That is a half-landed restore, and reporting
    /// success for it is the failure this case exists to prevent.
    case luaOwnsThisMac
}
