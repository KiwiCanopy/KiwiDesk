import Foundation
import KiwiDeskCore

/// Following a sync folder as Settings shows it (#2324 slice 3).
struct SettingsSyncState: Equatable {
    /// Where following stands, from `KiwiCore.sync`.
    var status: SyncStatus = .off
    /// The last change another Mac brought in while the draft held
    /// edits — the strip's subject; nil once the draft is clean.
    var arrived: SyncedChange?
    /// Settings both Macs changed, picked in one sheet at Save.
    var conflicts: [SyncConflict] = []
    /// Settings another Mac changed that the draft took in without
    /// a question, for the sheet's summary line.
    var taken: Set<SettingKey> = []
    /// The sheet Save is showing now (#2450).
    var review: SyncReview?
}

/// A setting this draft and another Mac both changed (#2324 ruling
/// 4); `key` nil is `init.lua`, which is asked about as one file.
struct SyncConflict: Identifiable, Equatable {
    let key: SettingKey?
    let label: String
    let yours: String
    let theirs: String
    let mac: String?
    /// Every setting the question answers: its own key, and any
    /// the key's writer laid an edit over.
    var covers: Set<SettingKey> = []

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
        let previousTaken = sync.taken
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
        // It is asked as the edited setting whose writer covers it,
        // since either answer moves both together.
        let clobbered = Set(
            SettingsDraftDiff.between(config: config, cleanConfig: theirs)
                .changedSettings
        )
        for key in incoming
        where !mine.contains(key) && clobbered.contains(key) {
            let owner = mine.first { Self.sharesWriter($0, key) } ?? key
            let covered = conflicts.first { $0.key == owner }?.covers ?? []
            conflicts.removeAll { $0.key == owner }
            var question = clobberConflict(
                key,
                asking: owner,
                yours: yours,
                theirs: theirs,
                base: base
            ).with(mac: change.mac)
            question.covers = covered.union([owner, key])
            conflicts.append(question)
        }
        if yoursLua != baseLua, theirsLua != baseLua {
            conflicts.removeAll { $0.key == nil }
            conflicts.append(Self.luaConflict(mac: change.mac))
        }
        reachEdits = reach
        lookReachEdits = look
        suppressDirty = false
        recomputeDirty()
        let asked = conflicts.reduce(into: Set<SettingKey>()) {
            $0.formUnion($1.covers)
            if let key = $1.key { $0.insert(key) }
        }
        sync.arrived = isDirty ? change : nil
        sync.conflicts = isDirty ? conflicts : []
        // Kept per member: the sheet folds it where it counts.
        sync.taken =
            isDirty
            ? previousTaken.union(incoming).subtracting(asked) : []
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
            label: SettingsValueReadout.label(for: key),
            yours: Self.value(of: mine.first),
            theirs: Self.value(of: other.first),
            mac: nil
        )
    }

    /// The question for `key`, whose change `owner`'s writer laid
    /// an edit over: the draft's value of `owner` against the other
    /// Mac's change to `key`.
    private func clobberConflict(
        _ key: SettingKey,
        asking owner: SettingKey,
        yours: GuiConfig,
        theirs: GuiConfig,
        base: GuiConfig
    ) -> SyncConflict {
        let lost = SettingsValueReadout.rows(
            for: key,
            old: theirs,
            new: config
        )
        let mine =
            owner == key
            ? lost.first?.newValue ?? lost.first?.changeNote
            : Self.value(
                of: SettingsValueReadout.rows(
                    for: owner,
                    old: base,
                    new: yours
                ).first
            )
        let other = SettingsValueReadout.rows(for: key, old: base, new: theirs)
        return SyncConflict(
            key: owner,
            label: SettingsValueReadout.label(for: owner),
            yours: mine ?? "",
            theirs: Self.value(of: other.first),
            mac: nil
        )
    }

    /// Whether one writer copies leaves of both keys.
    private static func sharesWriter(_ a: SettingKey, _ b: SettingKey) -> Bool
    {
        let writers = SettingsRevertRegister.writers
        guard let left = writers[a]?.paths, let right = writers[b]?.paths
        else { return false }
        return !Set(left).isDisjoint(with: right)
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
}

extension SyncConflict {
    func with(mac: String?) -> SyncConflict {
        SyncConflict(
            key: key,
            label: label,
            yours: yours,
            theirs: theirs,
            mac: mac,
            covers: covers
        )
    }
}
