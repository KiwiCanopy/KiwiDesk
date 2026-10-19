import Foundation
import KiwiDeskCore

/// Which side of a conflict the sync sheet keeps.
enum SyncChoice: Hashable {
    case yours
    case theirs
}

/// Every setting both Macs changed, shown in one sheet at Save
/// (#2450): a group one control writes is one row while the
/// draft's members agree, and every row is picked on purpose.
struct SyncReview: Identifiable, Equatable {
    struct Row: Identifiable, Equatable {
        /// The census key a Theirs pick takes back — a group's
        /// master for a folded row — or nil for `init.lua`.
        let key: SettingKey?
        let label: String
        let yours: String
        let theirs: String

        var id: String { key?.id ?? SyncConflict.initLua }
    }

    let rows: [Row]
    /// The Mac every conflict came from, nil when unknown or mixed.
    let mac: String?
    /// The other Mac's changes the draft took in unasked.
    let taken: Int
    /// The draft's edits that save as they are.
    let yourOthers: Int

    var id: [String] { rows.map(\.id) }
}

extension SettingsModel {
    /// Shows the sheet for the conflicts still standing, or answers
    /// false when none is left and Save may write.
    func reviewSyncConflicts() -> Bool {
        let edited = SettingsDraftDiff.between(
            config: config,
            cleanConfig: cleanConfig
        ).changedSettings
        // A setting reverted since stops being a question.
        sync.conflicts.removeAll { conflict in
            guard let key = conflict.key else {
                return luaSource == cleanLuaSource
            }
            return !edited.contains(key)
        }
        guard !sync.conflicts.isEmpty else { return false }
        sync.review = syncReview(edited: edited)
        return true
    }

    /// Applies the sheet's picks — Theirs takes a row back from the
    /// baseline, which holds the other Mac's value — then saves.
    func answerSyncReview(_ picks: [String: SyncChoice]) {
        guard let review = sync.review else { return }
        sync.review = nil
        sync.conflicts = []
        for row in review.rows where picks[row.id] == .theirs {
            if let key = row.key {
                SettingsRevertRegister.writers[key]?.apply(self, nil)
            } else {
                luaSource = cleanLuaSource
            }
        }
        recomputeDirty()
        DispatchQueue.main.async { [weak self] in
            self?.performPrimarySave()
        }
    }

    /// Cancel: nothing saves, and every conflict waits for the next
    /// Save.
    func cancelSyncReview() {
        sync.review = nil
    }

    private func syncReview(edited: [SettingKey]) -> SyncReview {
        var rows: [SyncReview.Row] = []
        var folded: Set<SettingKey> = []
        for conflict in sync.conflicts {
            guard let key = conflict.key,
                let master = key.summaryMaster,
                SettingKey.summarizes(master, in: config)
            else {
                rows.append(
                    SyncReview.Row(
                        key: conflict.key,
                        label: conflict.label,
                        yours: conflict.yours,
                        theirs: conflict.theirs
                    )
                )
                continue
            }
            guard folded.insert(master).inserted else { continue }
            rows.append(
                SyncReview.Row(
                    key: master,
                    label: SettingsValueReadout.label(for: master),
                    yours: groupValue(master, in: config, from: cleanConfig),
                    theirs: groupValue(master, in: cleanConfig, from: config)
                )
            )
        }
        let macs = Set(sync.conflicts.map(\.mac))
        let asked = Set(rows.compactMap(\.key))
            .union(sync.conflicts.compactMap(\.key))
        let others = SettingKey.summarized(edited, in: config)
            .filter { !asked.contains($0) }
        let luaOther =
            luaSource != cleanLuaSource && !rows.contains { $0.key == nil }
        return SyncReview(
            rows: rows,
            mac: macs.count == 1 ? macs.first ?? nil : nil,
            taken: sync.taken.count,
            yourOthers: others.count + (luaOther ? 1 : 0)
        )
    }

    /// A group's value in `side`: one value while its members
    /// agree, else "mixed" with each member's value.
    private func groupValue(
        _ master: SettingKey,
        in side: GuiConfig,
        from other: GuiConfig
    ) -> String {
        guard !SettingKey.summarizes(master, in: side) else {
            return SettingsValueReadout.rows(
                for: master,
                old: other,
                new: side
            ).first?.newValue ?? ""
        }
        let members = SettingKey.summaryGroups[master] ?? []
        return SyncText.mixed(
            members.map { member in
                SyncText.memberValue(
                    SettingsValueReadout.label(for: member),
                    SettingsValueReadout.rows(
                        for: member,
                        old: other,
                        new: side
                    ).first?.newValue ?? ""
                )
            }
        )
    }
}
