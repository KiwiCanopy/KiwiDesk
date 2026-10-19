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
    /// baseline, which holds the other Mac's value — then saves; a
    /// conflict the sheet did not show is shown at that Save.
    func answerSyncReview(_ picks: [String: SyncChoice]) {
        guard let review = sync.review else { return }
        sync.review = nil
        let shown = Set(review.rows.compactMap(\.key))
        sync.conflicts.removeAll { conflict in
            guard let key = conflict.key else {
                return review.rows.contains { $0.key == nil }
            }
            return shown.contains(key)
                || key.summaryMaster.map(shown.contains) == true
        }
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
        // The one fold the pill takes, over the draft's side.
        let shown = Set(
            SettingKey.summarized(
                sync.conflicts.compactMap(\.key),
                in: config
            )
        )
        var rows: [SyncReview.Row] = []
        for conflict in sync.conflicts {
            guard let key = conflict.key, !shown.contains(key),
                let master = key.summaryMaster
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
            guard !rows.contains(where: { $0.key == master }) else {
                continue
            }
            rows.append(
                SyncReview.Row(
                    key: master,
                    label: SettingsValueReadout.label(for: master),
                    yours: groupValue(master, in: config, from: cleanConfig),
                    theirs: groupValue(master, in: cleanConfig, from: config)
                )
            )
        }
        var asked = Set(rows.compactMap(\.key))
        for conflict in sync.conflicts {
            asked.formUnion(conflict.covers)
            if let key = conflict.key { asked.insert(key) }
        }
        for row in rows {
            asked.formUnion(
                row.key.flatMap { SettingKey.summaryGroups[$0] } ?? []
            )
        }
        let others = SettingKey.summarized(
            edited.filter { !asked.contains($0) },
            in: config,
            apart: asked
        )
        let taken = SettingKey.summarized(
            sync.taken.subtracting(asked).sorted { $0.id < $1.id },
            in: cleanConfig,
            apart: asked
        )
        let luaOther =
            luaSource != cleanLuaSource && !rows.contains { $0.key == nil }
        let macs = Set(sync.conflicts.map(\.mac))
        return SyncReview(
            rows: rows,
            mac: macs.count == 1 ? macs.first ?? nil : nil,
            taken: taken.count,
            yourOthers: others.count + (luaOther ? 1 : 0)
        )
    }

    /// A group's value in `side`: its master's readout while every
    /// axis agrees, else "mixed" with each member's own row.
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
            members.compactMap { member in
                SettingsValueReadout.rows(
                    for: member,
                    old: other,
                    new: side
                ).first.map {
                    SyncText.memberValue($0.label, $0.newValue ?? "")
                }
            }
        )
    }
}
