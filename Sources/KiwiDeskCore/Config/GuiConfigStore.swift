import Foundation

/// Reads and writes GUI configuration sidecar `gui.json` — the
/// visual editor's source of truth; it also captures what live
/// Lua state can't reconstruct (keybinding actions, mode
/// icons).
public struct GuiConfigStore {
    let url: URL

    /// The Space each Desktop is showing RIGHT NOW (#1230), which
    /// every write stamps in over whatever the caller's copy
    /// holds.
    ///
    /// Eight call sites write this sidecar and most hand back a
    /// config they loaded earlier and edited, so a Settings save
    /// would write that copy's stale Desktop memory over what the
    /// session has since learned — losing it silently. Stamping at
    /// the WRITE makes every one of them correct by construction
    /// rather than by each remembering.
    ///
    /// Carried as a VALUE rather than a closure because
    /// `KiwiCore.guiConfigStore` is computed: every access builds
    /// a store, so the value is read immediately before the save
    /// it feeds. A caller that held a store across time would
    /// stamp a stale map — nothing does, and nothing should.
    ///
    /// Empty by default, and empty means "do not stamp", so a
    /// test writing a config gets exactly what it passed.
    public var liveDesktopSpaces: [DesktopKey: SpaceID] = [:]

    public init(directory: URL) {
        self.url = directory.appendingPathComponent("gui.json")
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Loads the sidecar, or nil on failure. Migrates older
    /// formats through `ConfigMigration` first and writes the
    /// migrated bytes back.
    public func load() -> GuiConfig? {
        guard var data = try? Data(contentsOf: url) else {
            return nil
        }
        if let migrated = ConfigMigration.migrated(data) {
            data = migrated
            try? migrated.write(to: url, options: .atomic)
        }
        return try? JSONDecoder().decode(
            GuiConfig.self,
            from: data
        )
    }

    public func save(_ config: GuiConfig) throws {
        var config = config
        if !liveDesktopSpaces.isEmpty {
            config.desktopSpaces = liveDesktopSpaces
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        try encoder.encode(config).write(
            to: url,
            options: .atomic
        )
    }
}
