import Foundation
import KiwiDeskCore

/// Following a sync folder as Settings shows it (#2324 slice 3).
struct SettingsSyncState: Equatable {
    /// Where following stands, from `KiwiCore.sync`.
    var status: SyncStatus = .off
    /// The last change another Mac brought in while the draft held
    /// edits — the strip's subject; nil once the draft is clean.
    var arrived: SyncedChange?
    /// Settings both Macs changed, asked about one by one at Save.
    var conflicts: [SyncConflict] = []
    /// The conflict Save is asking about now.
    var question: SyncConflict?
}

/// A setting this draft and another Mac both changed (#2324 ruling
/// 4); `key` nil is `init.lua`, which is asked about as one file.
struct SyncConflict: Identifiable, Equatable {
    let key: SettingKey?
    let label: String
    let yours: String
    let theirs: String
    let mac: String?

    var id: String { key?.id ?? Self.initLua }

    static let initLua = "init.lua"
}

/// A change the sync folder brought in, entering the draft (#2324
/// ruling 4): a clean draft re-reads; a draft with edits takes the
/// other Mac's changes to every setting it did not edit, keeps its
/// own, and remembers each setting both changed for one question at
/// Save. The strip says the setup changed meanwhile.
extension SettingsModel {
    func adoptSyncedChange(_ change: SyncedChange) {
        guard isDirty else {
            reload()
            return
        }
        let yours = config
        let yoursLua = luaSource
        let base = cleanConfig
        let baseLua = cleanLuaSource
        let reach = reachEdits
        let look = lookReachEdits
        let previous = sync.conflicts
        reload()
        let theirs = cleanConfig
        let theirsLua = cleanLuaSource
        let mine = SettingsDraftDiff.between(config: yours, cleanConfig: base)
            .changedSettings
        let incoming = Set(
            SettingsDraftDiff.between(config: theirs, cleanConfig: base)
                .changedSettings
        )
        suppressDirty = true
        // Each writer copies `cleanConfig` into the draft, so the
        // draft's own edits are laid back from a baseline of them.
        cleanConfig = yours
        for key in mine {
            SettingsRevertRegister.writers[key]?.apply(self, nil)
        }
        cleanConfig = theirs
        if yoursLua != baseLua { luaSource = yoursLua }
        // An earlier arrival's question stands while its edit does.
        var conflicts = previous.filter { old in
            guard let key = old.key else { return luaSource != theirsLua }
            return mine.contains(key)
        }
        func ask(_ key: SettingKey, yours: GuiConfig) {
            conflicts.removeAll { $0.key == key }
            conflicts.append(
                conflict(key, yours: yours, theirs: theirs, base: base)
                    .with(mac: change.mac)
            )
        }
        for key in mine where incoming.contains(key) {
            ask(key, yours: yours)
        }
        // A writer that copies more than its own key — a master and
        // its followers, a whole per-instance map — may have laid an
        // edit back over the other Mac's change to a setting the
        // draft never touched: that becomes a question, not a loss.
        let clobbered = Set(
            SettingsDraftDiff.between(config: config, cleanConfig: theirs)
                .changedSettings
        )
        for key in incoming
        where !mine.contains(key)
            && clobbered.contains(key)
        {
            ask(key, yours: config)
        }
        if yoursLua != baseLua, theirsLua != baseLua {
            conflicts.removeAll { $0.key == nil }
            conflicts.append(Self.luaConflict(mac: change.mac))
        }
        reachEdits = reach
        lookReachEdits = look
        suppressDirty = false
        recomputeDirty()
        sync.arrived = isDirty ? change : nil
        sync.conflicts = isDirty ? conflicts : []
    }

    private func conflict(
        _ key: SettingKey,
        yours: GuiConfig,
        theirs: GuiConfig,
        base: GuiConfig
    ) -> SyncConflict {
        let mine = SettingsValueReadout.rows(for: key, old: base, new: yours)
        let other = SettingsValueReadout.rows(for: key, old: base, new: theirs)
        return SyncConflict(
            key: key,
            label: mine.first?.label ?? other.first?.label ?? key.id,
            yours: Self.value(of: mine.first),
            theirs: Self.value(of: other.first),
            mac: nil
        )
    }

    private static func value(of row: SettingsDiffRow?) -> String {
        row?.newValue ?? row?.changeNote ?? ""
    }

    private static func luaConflict(mac: String?) -> SyncConflict {
        SyncConflict(
            key: nil,
            label: SyncConflict.initLua,
            yours: SyncText.yourEdits,
            theirs: SyncText.theirEdits,
            mac: mac
        )
    }

    // MARK: - The question at Save

    /// Asks about the next conflict, or answers false when none is
    /// left and Save may write.
    func askNextSyncConflict() -> Bool {
        // A setting reverted since stops being a question.
        let edited = SettingsDraftDiff.between(
            config: config,
            cleanConfig: cleanConfig
        ).changedSettings
        sync.conflicts.removeAll { conflict in
            guard let key = conflict.key else {
                return luaSource == cleanLuaSource
            }
            return !edited.contains(key)
        }
        guard let next = sync.conflicts.first else { return false }
        sync.question = next
        return true
    }

    /// Settles the question: theirs takes the setting back from the
    /// baseline, which holds the other Mac's value; yours keeps the
    /// draft. The next question follows, then the Save.
    func answerSyncConflict(useTheirs: Bool) {
        guard let question = sync.question else { return }
        sync.question = nil
        sync.conflicts.removeAll { $0.id == question.id }
        if useTheirs {
            if let key = question.key {
                SettingsRevertRegister.writers[key]?.apply(self, nil)
            } else {
                luaSource = cleanLuaSource
            }
            recomputeDirty()
        }
        DispatchQueue.main.async { [weak self] in
            self?.performPrimarySave()
        }
    }

    /// Cancel: nothing saves, and every question waits for the
    /// next Save.
    func cancelSyncConflict() {
        sync.question = nil
    }
}

extension SyncConflict {
    func with(mac: String?) -> SyncConflict {
        SyncConflict(
            key: key,
            label: label,
            yours: yours,
            theirs: theirs,
            mac: mac
        )
    }
}
