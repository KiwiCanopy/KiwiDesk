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
    ///
    /// Deliberately NOT run through `ConfigMigration`, unlike
    /// `ProfileManager.read`: `GuiConfig.encode(to:)` writes only
    /// the spaces, rules, bindings and layers — never `settings`,
    /// which `GuiConfig.CodingKeys` has no case for either —
    /// so no `gui.json` this app has ever written can carry a
    /// bar-content value to migrate. A hop here would be a
    /// crossing for a case that cannot arise. The day this
    /// sidecar starts persisting `settings`, it owes one.
    public func load() -> GuiConfig? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
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
