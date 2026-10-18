import Foundation

/// Pending Desktop bindings — a name bound before any profile
/// carried it, or one stored before ids existed — given the id of
/// the profile they name, once it exists (#2324 ruling 11). The
/// gate resolves a pending entry by name meanwhile, so this only
/// makes the stored map follow a later rename.
extension KiwiCore {
    /// Promotes every pending entry of the stored bindings — never
    /// a Lua line's, which lives in the runtime map alone — and
    /// mirrors the result into the runtime map. Runs at a config
    /// load and after a profile is saved, renamed or copied.
    func promotePendingBindings() {
        guard isGuiManaged else { return }
        var map = guiConfigStore.bindingsFile.load().profileBindings
        var changed = false
        for key in map.keys where map[key]?.promote(pendingID) == true {
            changed = true
        }
        guard changed else { return }
        do {
            try guiConfigStore.saveBindings(map)
        } catch {
            onLog("desktop bindings: promotion write failed: \(error)")
        }
        for (key, binding) in map { desktopBindings[key] = binding }
    }

    /// The id a pending name takes: the profile saved under that
    /// name, else one written before ids existed and renamed since,
    /// which carries the name's legacy id.
    func pendingID(_ name: String) -> ProfileID? {
        if let profile = try? profiles.read(name: name) {
            return profile.id
        }
        let legacy = ProfileID.legacy(name: name)
        return profiles.profileName(withID: legacy) == nil ? nil : legacy
    }
}
