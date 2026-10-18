import Foundation

/// Pending Desktop bindings — a name bound before any profile
/// carried it, or one stored before ids existed — given the id of
/// the profile they name, once it exists (#2324 ruling 11). The
/// gate resolves a pending entry by name meanwhile, so this only
/// makes the stored map follow a later rename. The same pass sets
/// an id entry's label to its profile's current name, so a rename
/// made on another Mac reaches every row and readout here.
extension KiwiCore {
    /// Promotes every pending entry of the stored bindings — never
    /// a Lua line's, which lives in the runtime map alone — and
    /// promotes the runtime map in place. Runs at a config load and
    /// after every profile write (`ProfileManager.onProfileWritten`).
    func promotePendingBindings() {
        guard isGuiManaged else { return }
        var map = guiConfigStore.bindingsFile.load().profileBindings
        var changed = false
        for key in map.keys {
            if map[key]?.promote(pendingID) == true { changed = true }
            if map[key]?.refreshLabels(currentLabel) == true {
                changed = true
            }
        }
        // The runtime map promotes in place, so an entry it holds
        // beside the stored one keeps its record.
        for key in desktopBindings.keys {
            desktopBindings[key]?.promote(pendingID)
            desktopBindings[key]?.refreshLabels(currentLabel)
        }
        guard changed else { return }
        do {
            try guiConfigStore.saveBindings(map)
        } catch {
            onLog("desktop bindings: promotion write failed: \(error)")
        }
    }

    /// The name an id's readable profile stores, from the index —
    /// no file is read.
    private func currentLabel(_ id: ProfileID) -> String? {
        guard let holder = profiles.holder(of: id), holder.readable
        else { return nil }
        return holder.storedName.isEmpty ? holder.file : holder.storedName
    }
}
