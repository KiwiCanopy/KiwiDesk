import Foundation

/// Reads and writes GUI configuration sidecar `gui.json` — the
/// visual editor's source of truth; it also captures what live
/// Lua state can't reconstruct (keybinding actions, mode
/// icons). The `GuiConfig.machineLocalFields` ride
/// `machine.json` in the machine folder instead (#2324): this
/// store is the one place the two files are composed and split.
public struct GuiConfigStore {
    let url: URL
    let machine: MachineConfigStore
    let bindingsFile: DesktopBindingsStore

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
    /// nil means "nothing to stamp" — a test writing a config
    /// gets exactly what it passed. An EMPTY map is not nil: it
    /// is a cleared memory, and treating the two alike made the
    /// map unclearable through its own write path, so a discard
    /// left the file's copy standing for the next boot to adopt.
    public var liveDesktopSpaces: [DesktopKey: SpaceID]?

    /// The live app-wide settings (#1741), stamped the same way
    /// and for the same reason. nil while the crossing is owed, so
    /// no write can end it with values it never adopted.
    public var liveAppWide: AppWideSettings?

    /// The shared look (#1752), stamped the same way: nil while its
    /// crossing is owed or the config is Lua-owned.
    public var liveLook: LookBody?

    /// Where a migrated rewrite keeps the original (#1880), set by
    /// the core that owns the config directory; nil keeps none.
    var migrationBackups: URL?

    /// `machine` is `MachineLocation`'s folder, or a test's own;
    /// no default, so no store writes the real one by accident.
    public init(directory: URL, machine: URL) {
        self.url = directory.appendingPathComponent("gui.json")
        self.machine = MachineConfigStore(directory: machine)
        self.bindingsFile = DesktopBindingsStore(directory: machine)
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Loads the sidecar with this Mac's leaves composed in, or
    /// nil on failure. Migrates older formats through
    /// `ConfigMigration` first and writes the migrated bytes back
    /// — once the leaves that step strips are carried into
    /// `machine.json`; a failed carry migrates in memory only and
    /// composes the leaves it still owes.
    public func load() -> GuiConfig? {
        guard var data = try? Data(contentsOf: url) else {
            return nil
        }
        let owed = machine.carry(fromLegacy: data)
        let owedBindings = bindingsFile.carry(fromLegacy: data)
        data = MigrationBackup.migrateInPlace(
            data,
            at: url,
            backups: migrationBackups,
            writesBack: owed == nil && owedBindings == nil
        )
        guard
            let config = try? JSONDecoder().decode(
                GuiConfig.self,
                from: data
            )
        else { return nil }
        return (owedBindings ?? bindingsFile.load()).applied(
            to: (owed ?? machine.load()).applied(to: config)
        )
    }

    /// Writes the sidecar; throws `NewerFormatOnDisk` rather than
    /// replace one a newer build wrote (#2325).
    public func save(_ config: GuiConfig) throws {
        try NewerFormatOnDisk.refuse(url, GuiConfig.currentFormat)
        try NewerFormatOnDisk.refuse(
            machine.url,
            MachineConfig.currentFormat
        )
        var config = config
        if let liveDesktopSpaces {
            config.desktopSpaces = liveDesktopSpaces
        }
        if let liveAppWide {
            config.appWide = liveAppWide
        }
        if let liveLook {
            config.look = liveLook
        }
        // This Mac's file first: a failed write here leaves the
        // shared file as it was, and with it any carry still owed.
        try machine.save(MachineConfig(of: config))
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

    /// Writes the live Desktop memory into `machine.json` alone,
    /// leaving `gui.json` — which another Mac may share — unread
    /// and untouched; nothing to write while there is no stamp.
    public func saveMachineLocal() throws {
        guard let liveDesktopSpaces else { return }
        var stored = machine.load()
        stored.desktopSpaces = liveDesktopSpaces
        try machine.save(stored)
    }

    /// `save`, with the config's WHOLE binding map written first —
    /// for the writers that author it whole: the Lua adoption and a
    /// restore. A Settings Save writes its edits per entry through
    /// `KiwiCore.rewriteSidecarBindings`, and every other `gui.json`
    /// write leaves `bindings.json` alone, so a stale copy never
    /// reverts a re-key or a promotion made since (#2324).
    public func saveIncludingBindings(_ config: GuiConfig) throws {
        try saveBindings(config.profileBindings)
        try save(config)
    }

    /// Writes the Desktop bindings into `bindings.json` alone —
    /// its one write door, and this Mac's file, so a machine event
    /// (a re-key) writes nothing another Mac shares (#2324).
    public func saveBindings(
        _ map: [DesktopKey: DesktopBinding]
    ) throws {
        var file = bindingsFile.load()
        file.profileBindings = map
        try bindingsFile.save(file)
    }
}
