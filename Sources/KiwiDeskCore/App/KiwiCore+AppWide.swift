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
    /// The animation lengths by profile name (#3237), owed while
    /// `gui.json` lacks their group — a crossing of its own, since
    /// an install that adopted #1741's has ended that one.
    var owedPace: [String: AppWideSettings.Animations]?
    /// A backup's inline lengths, paired with its bundle as above.
    var backupPace:
        (bundle: SetupBundle, owed: [String: AppWideSettings.Animations])?

    /// Whether either crossing is owed.
    var owes: Bool { owed != nil || owedPace != nil }

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

    /// The stored app-wide values, without a verb's session change:
    /// what a Settings table reads as its shared base (#3089).
    var appWideSettled: AppWideSettings { appWideLedger.settled }

    /// What every `gui.json` write stamps in
    /// (`GuiConfigStore.liveAppWide`): the settled values once
    /// stored, never a verb's session change.
    var appWideStamp: AppWideSettings? {
        guard appWideLedger.isStored else { return nil }
        // The ledger decides whether the lengths are stored (#3237).
        var stamp = appWideLedger.settled
        stamp.animationPaceStored = appWideLedger.owedPace == nil
        return stamp
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
            // `init.lua` is the store, and the Hyper key a remapped
            // physical key: a reload whose file no longer calls
            // `set_hyper_key` gives it back, as a relaunch would.
            // The change only owes a deferred remap, so `init.lua`
            // setting it again remaps nothing in between (#1870).
            appWideLedger.live.hyperKey = nil
            // KiwiHub's keys likewise (#2600): a line moved or
            // removed reads as written, not as the last load left it.
            appWideLedger.live.kiwiHubKeys = KiwiHubKeys()
            // The sides too (#2601), applied at once: a line removed
            // reads off, and init.lua setting it again re-arms.
            appWideLedger.live.modifierSides = false
            // The tiling-off bases too (#3008, #3089): a line removed
            // reads the default.
            appWideLedger.live.tilingStartGlobal = true
            appWideLedger.live.tilingOffHidesBorders = false
            appWideLedger.live.tilingOffHidesBars = false
            // The lengths too (#3237): a line removed reads the default.
            appWideLedger.owedPace = nil
            appWideLedger.live.adoptPace(AppWideSettings().animations)
            return
        }
        guard let config = guiConfigStore.load() else { return }
        if let stored = config.appWide {
            appWideLedger = AppWideLedger(stored, stored: true)
            if !stored.animationPaceStored { capturePace() }
            return
        }
        appWideLedger.isStored = false
        capturePace()
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

    /// The lengths every profile file carries, read from its
    /// migrated bytes, owed until the crossing ends (#3237).
    private func capturePace() {
        guard appWideLedger.owedPace == nil else { return }
        var owed: [String: AppWideSettings.Animations] = [:]
        for name in profiles.list() {
            guard let url = try? profiles.fileURL(name: name),
                let data = try? Data(contentsOf: url),
                let pace = ConfigMigration.legacyPace(inProfile: data)
            else { continue }
            owed[name] = pace
        }
        appWideLedger.owedPace = owed
    }

    /// A capture is the FILE's, filed under its name (#1975): a
    /// deleted profile's leaves with it, and a renamed one's
    /// follows it, so a later profile under that name never
    /// adopts another file's values.
    func forgetAppWideCapture(of name: String) {
        appWideLedger.owed?[name] = nil
        appWideLedger.owedPace?[name] = nil
    }

    /// A restore that replaces the profiles without a `gui.json`
    /// (#1975): every capture named a replaced file, so the
    /// reload re-captures from the restored ones.
    func forgetAppWideCaptures() {
        appWideLedger.owed = nil
        appWideLedger.backup = nil
        appWideLedger.owedPace = nil
        appWideLedger.backupPace = nil
    }

    /// `forgetAppWideCapture`'s rename twin (#1975).
    func renameAppWideCapture(_ old: String, to new: String) {
        if let captured = appWideLedger.owed?[old] {
            appWideLedger.owed?[old] = nil
            appWideLedger.owed?[new] = captured
        }
        if let pace = appWideLedger.owedPace?[old] {
            appWideLedger.owedPace?[old] = nil
            appWideLedger.owedPace?[new] = pace
        }
    }

    /// Ends an owed crossing at the first profile apply with the
    /// incoming — live — profile's captured values; a profile that
    /// carried none keeps the settled ones (the defaults at an
    /// upgrade, this Mac's own at a restore).
    func adoptAppWide(from profile: Profile) {
        guard appWideLedger.owes, isGuiManaged else { return }
        endCrossing(adopting: appWideLedger.crossingValue(for: profile.name))
    }

    /// The settled lenses: what the Settings lens page seeds its
    /// draft from and writes back, so a session `define_lens` or
    /// `delete_lens` never reaches `gui.json` (ruling 40).
    public var kiwiVisionStoredLenses: [VisionLens] {
        appWideLedger.settled.visionLenses
    }

    /// The lenses `gui.json` holds now — none before its group is
    /// stored, since settled values a crossing owes are in no file —
    /// and nil for a Lua-owned setup, whose store is `init.lua`.
    var kiwiVisionLensesInGuiJSON: [VisionLens]? {
        isGuiManaged ? appWideStamp?.visionLenses ?? [] : nil
    }

    /// A General row (`persisting`) or a verb changing a value. A
    /// row writes `gui.json` at once — ending an owed crossing
    /// through the same door the first apply takes, after which
    /// the engine runs what was stored — and a verb changes the
    /// session alone, as every `set_*` does. No default: a caller
    /// says which it is. A write that renames a lens says so in
    /// `renamingLens`, so the lens on follows it — for this write
    /// alone (#2103); the writer re-keys the stored bindings and
    /// every profile's `lens_reach` in the same save
    /// (`VisionLens.reach`).
    public func setAppWide(
        persisting: Bool,
        renamingLens: (from: String, to: String)? = nil,
        _ change: (inout AppWideSettings) -> Void
    ) {
        vision.renamedLens = renamingLens
        defer { vision.renamedLens = nil }
        change(&appWideLedger.live)
        // A Lua-owned config has no store to write (its rows grey).
        guard persisting, isGuiManaged else { return }
        if appWideLedger.owes {
            var value = appWideLedger.crossingValue(for: profiles.currentName)
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
    /// once that write landed. A lens leaves its Lua-only overrides
    /// behind, which Settings draws no row for (#3246).
    func storeLiveAppWide() {
        var value = appWideLedger.live
        value.adoptPace(value.animations)
        value.visionLenses = value.visionLenses.map(\.settingsDrawn)
        appWideLedger = AppWideLedger(value, stored: true)
    }

    /// A backup read: the retired values its inline profiles
    /// carry, which their decode drops, kept with that bundle.
    func noteBackupAppWide(_ bundle: SetupBundle, bytes: Data) {
        appWideLedger.backup = (
            bundle,
            ConfigMigration.legacyAppWide(inBundle: bytes)
        )
        appWideLedger.backupPace = (
            bundle,
            ConfigMigration.legacyPace(inBundle: bytes)
        )
    }

    /// A restore takes the bundle's values. A bundle from before
    /// #1741 stores none: nothing is stamped over the restored
    /// file, and the crossing owes its profiles' values — read at
    /// `readBackup`, and only if this is that same bundle.
    func takeRestoredAppWide(from bundle: SetupBundle) {
        let read = appWideLedger.backup
        let readPace = appWideLedger.backupPace
        appWideLedger.backup = nil
        appWideLedger.backupPace = nil
        let owedPace =
            readPace.map { $0.bundle == bundle ? $0.owed : [:] } ?? [:]
        guard let bundled = bundle.config?.appWide else {
            appWideLedger.isStored = false
            appWideLedger.owed =
                read.map { $0.bundle == bundle ? $0.owed : [:] } ?? [:]
            appWideLedger.owedPace = owedPace
            return
        }
        appWideLedger = AppWideLedger(bundled, stored: true)
        if !bundled.animationPaceStored {
            appWideLedger.owedPace = owedPace
        }
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
        // The stamp reads the ledger: nothing is owed once stored.
        appWideLedger.owedPace = nil
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
                let raw = try? Data(contentsOf: url),
                // A newer build's file is not this build's (#2325).
                (try? NewerFormatOnDisk.refuseProfile(url)) != nil
            else { continue }
            // Migrated first: a step that rewrites a stripped key
            // (#3236's 0) reads it before the strip (profiles.md).
            let data = MigrationBackup.migrateInPlace(
                raw,
                at: url,
                backups: profiles.migrationBackups
            )
            guard let stripped = AppWideLedger.withoutRetiredAppWide(data)
            else { continue }
            do {
                try stripped.write(to: url, options: .atomic)
            } catch {
                onLog("app-wide settings: \(name) not rewritten: \(error)")
            }
        }
    }
}
