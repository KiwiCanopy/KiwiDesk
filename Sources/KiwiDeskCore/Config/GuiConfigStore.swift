import Foundation

/// Reads and writes GUI configuration sidecar `gui.json`.
public struct GuiConfigStore {
    let url: URL

    public init(directory: URL) {
        self.url = directory.appendingPathComponent("gui.json")
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Loads sidecar with ConfigMigration migration, or nil on failure.
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
