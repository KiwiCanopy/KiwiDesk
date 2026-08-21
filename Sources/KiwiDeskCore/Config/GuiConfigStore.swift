import Foundation

/// Reads and writes the GUI's `gui.json` sidecar — the visual
/// editor's source of truth. `init.lua`'s managed block is
/// regenerated from it; the sidecar additionally captures what
/// live Lua state can't reconstruct (keybinding actions, mode
/// icons).
public struct GuiConfigStore {
    let url: URL

    public init(directory: URL) {
        self.url = directory.appendingPathComponent("gui.json")
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Loads the sidecar, or nil if it is absent or unreadable.
    /// Migrates older format sidecars through `ConfigMigration`
    /// first and writes back the migrated bytes.
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
