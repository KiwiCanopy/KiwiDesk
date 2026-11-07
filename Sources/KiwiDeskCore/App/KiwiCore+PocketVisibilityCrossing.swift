import Foundation

/// The app-wide pocket capacity crosses onto each profile's
/// `kiwishelf.pocket_visibility` (#2978 ruling 7): an election N
/// files cannot hold alone, since a profile file cannot read
/// `gui.json`. Run first at a config load, ahead of every `gui.json`
/// write, so no writer drops the retired group before it is read.
extension KiwiCore {
    /// Stamps every profile file that states no pocket Show from
    /// `gui.json`'s retired `pocket.capacity`, then drops the group —
    /// only once every write landed, so a failed one crosses again at
    /// the next load. A newer build's file is left alone; a composed
    /// Standard has no file and takes the default.
    func crossPocketVisibility() {
        guard isGuiManaged,
            let data = try? Data(contentsOf: guiConfigStore.url),
            let capacity = ConfigMigration.retiredPocketCapacity(in: data),
            let config = guiConfigStore.load()
        else { return }
        var landed = true
        for name in profiles.list() {
            guard let url = try? profiles.fileURL(name: name),
                let data = try? Data(contentsOf: url),
                (try? NewerFormatOnDisk.refuseProfile(url)) != nil,
                let root = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                let settings = root[ConfigMigration.barEdgeSettingsKey]
                    as? [String: Any],
                !ConfigMigration.statesPocketVisibility(settings),
                let profile = try? profiles.read(name: name)
            else { continue }
            let value = ConfigMigration.crossedPocketVisibility(
                capacity: capacity,
                settings: profile.settings
            )
            do {
                guard
                    let crossed = ConfigMigration.withPocketVisibility(
                        value,
                        in: data
                    )
                else { throw CocoaError(.fileWriteUnknown) }
                try crossed.write(to: url, options: .atomic)
            } catch {
                landed = false
                onLog("pocket visibility: \(name) not crossed: \(error)")
            }
        }
        guard landed else { return }
        do {
            // The coder no longer writes the group, so a save drops it.
            try guiConfigStore.save(config)
        } catch {
            onLog("pocket visibility: gui.json write failed: \(error)")
        }
    }
}
