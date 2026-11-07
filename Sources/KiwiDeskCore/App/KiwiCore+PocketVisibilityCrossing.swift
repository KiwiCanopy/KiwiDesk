import Foundation

/// The app-wide pocket capacity crosses onto each profile's
/// `kiwishelf.pocket_visibility` (#2978 ruling 7): an election N
/// files cannot hold alone, since a profile file cannot read
/// `gui.json`. Run first at a config load, ahead of every `gui.json`
/// write, so no writer drops the retired group before it is read.
extension KiwiCore {
    /// Stamps every profile file that states no pocket Show from
    /// `gui.json`'s retired `pocket.capacity`, then drops the group —
    /// only once every file crossed, so one that failed or would not
    /// read crosses at the next load. A newer build's file is left
    /// alone; a composed Standard has no file and takes the default.
    func crossPocketVisibility() {
        guard isGuiManaged else { return }
        Self.crossPocketVisibility(
            gui: guiConfigStore,
            profiles: profiles,
            log: onLog
        )
    }

    /// The crossing over one setup's files: this Mac's, or a sync
    /// folder's staged copy before a take builds its bundle.
    static func crossPocketVisibility(
        gui guiConfigStore: GuiConfigStore,
        profiles: ProfileManager,
        log onLog: (String) -> Void
    ) {
        // Read through the migration, which states an older file's
        // absent group (`migratingAbsentPocketCapacity`), whether or
        // not the load below writes it back.
        guard let raw = try? Data(contentsOf: guiConfigStore.url),
            let capacity = ConfigMigration.retiredPocketCapacity(
                in: ConfigMigration.migrated(raw) ?? raw
            ),
            let config = guiConfigStore.load()
        else { return }
        var landed = true
        for name in profiles.list() {
            guard let url = try? profiles.fileURL(name: name),
                // A newer build's file is not this build's (#2325).
                (try? NewerFormatOnDisk.refuseProfile(url)) != nil
            else { continue }
            do {
                // The read migrates the file in place first, so the
                // insert lands on the bytes it left.
                let profile = try profiles.read(name: name)
                let data = try Data(contentsOf: url)
                guard
                    let root = try JSONSerialization.jsonObject(with: data)
                        as? [String: Any],
                    let settings = root[ConfigMigration.barEdgeSettingsKey]
                        as? [String: Any]
                else { throw CocoaError(.fileReadCorruptFile) }
                if ConfigMigration.statesPocketVisibility(settings) {
                    continue
                }
                let value = ConfigMigration.crossedPocketVisibility(
                    capacity: capacity,
                    settings: profile.settings
                )
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
