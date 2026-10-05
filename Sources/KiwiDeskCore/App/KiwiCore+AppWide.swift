import Foundation

/// The app-wide settings' states (#1741), one meaning each.
struct AppWideLedger {
    /// What the engine reads — a verb changes this alone.
    var live = AppWideSettings()
    /// `live` without any verb's session change: what a row write
    /// or an adoption builds on, and what `gui.json` carries.
    var settled = AppWideSettings()
    /// Whether `gui.json` carries `settled` — false until the
    /// crossing ends or a General row writes.
    var isStored = false
    /// The retired per-profile values by profile name, captured
    /// once a read of `gui.json` found none stored; nil while
    /// nothing is owed.
    var owed: [String: AppWideSettings]?
    /// The retired values a backup's inline profiles carry, with
    /// the bundle they were read from: a restore owes them only
    /// for that same bundle.
    var backup: (bundle: SetupBundle, owed: [String: AppWideSettings])?

    /// Every state at one value — a load, a restore, an adoption.
    init(
        _ value: AppWideSettings = AppWideSettings(),
        stored: Bool = false
    ) {
        live = value
        settled = value
        isStored = stored
    }
}

/// The settings no profile carries (#1741) — the one home of every
/// write to `appWideLedger` (`AppWideSeamTests`). A profile apply
/// never touches them; the engine reads `appWide`.
extension KiwiCore {
    public var appWide: AppWideSettings { appWideLedger.live }

    /// What every `gui.json` write stamps in
    /// (`GuiConfigStore.liveAppWide`): the settled values once
    /// stored, never a verb's session change.
    var appWideStamp: AppWideSettings? {
        appWideLedger.isStored ? appWideLedger.settled : nil
    }

    /// Reads `gui.json` at a config load, AHEAD of anything that
    /// may rewrite a profile file (the #1530 settle): stored
    /// values become live, and a file readable without them owes
    /// the crossing, whose values are captured now. An unreadable
    /// file owes nothing, and neither does a Lua-owned config,
    /// whose `init.lua` is the store.
    func prepareAppWide() {
        guard isGuiManaged else {
            appWideLedger.owed = nil
            return
        }
        guard let config = guiConfigStore.load() else { return }
        if let stored = config.appWide {
            appWideLedger = AppWideLedger(stored, stored: true)
            return
        }
        appWideLedger.isStored = false
        guard appWideLedger.owed == nil else { return }
        var owed: [String: AppWideSettings] = [:]
        for name in profiles.list() {
            guard let url = try? profiles.fileURL(name: name),
                let data = try? Data(contentsOf: url),
                let legacy = ConfigMigration.legacyAppWide(
                    inProfile: data
                )
            else { continue }
            owed[name] = legacy
        }
        appWideLedger.owed = owed
    }

    /// A capture is the FILE's, filed under its name (#1975): a
    /// deleted profile's leaves with it, and a renamed one's
    /// follows it, so a later profile under that name never
    /// adopts another file's values.
    func forgetAppWideCapture(of name: String) {
        appWideLedger.owed?[name] = nil
    }

    /// `forgetAppWideCapture`'s rename twin (#1975).
    func renameAppWideCapture(_ old: String, to new: String) {
        guard let captured = appWideLedger.owed?[old] else { return }
        appWideLedger.owed?[old] = nil
        appWideLedger.owed?[new] = captured
    }

    /// Ends an owed crossing at the first profile apply with the
    /// incoming — live — profile's captured values; a profile that
    /// carried none keeps the settled ones (the defaults at an
    /// upgrade, this Mac's own at a restore).
    func adoptAppWide(from profile: Profile) {
        guard let owed = appWideLedger.owed, isGuiManaged else {
            return
        }
        endCrossing(adopting: owed[profile.name] ?? appWideLedger.settled)
    }

    /// A General row (`persisting`) or a verb changing a value. A
    /// row writes `gui.json` at once — ending an owed crossing
    /// through the same door the first apply takes, after which
    /// the engine runs what was stored — and a verb changes the
    /// session alone, as every `set_*` does. No default: a caller
    /// says which it is.
    public func setAppWide(
        persisting: Bool,
        _ change: (inout AppWideSettings) -> Void
    ) {
        change(&appWideLedger.live)
        // A Lua-owned config has no store to write (its rows grey).
        guard persisting, isGuiManaged else { return }
        if let owed = appWideLedger.owed {
            var value =
                profiles.currentName.flatMap { owed[$0] }
                ?? appWideLedger.settled
            change(&value)
            endCrossing(adopting: value)
            return
        }
        change(&appWideLedger.settled)
        appWideLedger.isStored = true
        persistAppWide()
    }

    /// Lua-to-GUI adoption, the one stamp of `live`: there the
    /// verbs `init.lua` executed ARE the stored config. Called
    /// before the seeded `gui.json` is written; the caller strips
    /// once that write landed.
    func storeLiveAppWide() {
        appWideLedger = AppWideLedger(appWideLedger.live, stored: true)
    }

    /// A backup read: the retired values its inline profiles
    /// carry, which their decode drops, kept with that bundle.
    func noteBackupAppWide(_ bundle: SetupBundle, bytes: Data) {
        appWideLedger.backup = (
            bundle,
            ConfigMigration.legacyAppWide(inBundle: bytes)
        )
    }

    /// A restore takes the bundle's values. A bundle from before
    /// #1741 stores none: nothing is stamped over the restored
    /// file, and the crossing owes its profiles' values — read at
    /// `readBackup`, and only if this is that same bundle.
    func takeRestoredAppWide(from bundle: SetupBundle) {
        let read = appWideLedger.backup
        appWideLedger.backup = nil
        guard let bundled = bundle.config?.appWide else {
            appWideLedger.isStored = false
            appWideLedger.owed =
                read.map { $0.bundle == bundle ? $0.owed : [:] } ?? [:]
            return
        }
        appWideLedger = AppWideLedger(bundled, stored: true)
    }

    /// The #634 reset, which discards `gui.json` itself.
    func resetAppWide() {
        appWideLedger = AppWideLedger()
    }

    /// Ends the crossing: `value` is stored, and only once that
    /// write landed do the retired groups leave every profile file,
    /// so a failed write keeps them for the next launch.
    @discardableResult
    private func endCrossing(adopting value: AppWideSettings) -> Bool {
        let before = appWideLedger
        appWideLedger.settled = value
        appWideLedger.isStored = true
        guard persistAppWide() else {
            appWideLedger = before
            return false
        }
        appWideLedger = AppWideLedger(value, stored: true)
        stripLegacyAppWide()
        return true
    }

    /// Writes `gui.json` with the stamp; false where nothing
    /// landed.
    @discardableResult
    private func persistAppWide() -> Bool {
        guard let config = guiConfigStore.load() else {
            onLog("app-wide settings: gui.json unreadable, not saved")
            return false
        }
        do {
            try guiConfigStore.save(config)
            return true
        } catch {
            onLog("app-wide settings: gui.json write failed: \(error)")
            return false
        }
    }

    /// Drops the retired groups from every profile file, so they
    /// have no reader left to feed (AGENTS.md §5).
    func stripLegacyAppWide() {
        for name in profiles.list() {
            guard let url = try? profiles.fileURL(name: name),
                let data = try? Data(contentsOf: url),
                let stripped = ConfigMigration.withoutLegacyAppWide(
                    data
                )
            else { continue }
            do {
                try stripped.write(to: url, options: .atomic)
            } catch {
                onLog("app-wide settings: \(name) not rewritten: \(error)")
            }
        }
    }
}
