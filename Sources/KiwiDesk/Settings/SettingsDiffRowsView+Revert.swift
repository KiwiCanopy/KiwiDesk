import KiwiDeskCore
import SwiftUI

/// What a list's draft rows may revert (#792): the model's verdict
/// and revert, and whether the ↺ rests drawn — the popover's, which
/// is opened on purpose — or shows only on hover and focus, as the
/// panel's list beside the page does (owner ruling 2026-10-15).
@MainActor
struct DiffRowRevert {
    let alwaysVisible: Bool
    let can: (SettingsDiffRow) -> Bool
    /// Whether the row's ↺ takes every shortcut change back and so
    /// asks first (owner, 2026-10-19).
    let takesGroup: (SettingsDiffRow) -> Bool
    let perform: (SettingsDiffRow) -> Void

    init(model: SettingsModel, alwaysVisible: Bool) {
        self.alwaysVisible = alwaysVisible
        can = { [weak model] in model?.canRevert($0) ?? false }
        takesGroup = { [weak model] in
            model?.revertTakesGroup($0) ?? false
        }
        perform = { [weak model] in model?.revert($0) }
    }

    /// The ↺'s words: what it takes back — every shortcut change
    /// for a group, else the value it returns to, where the row
    /// states one. A label rather than a sentence, since a value
    /// may be a clause ("Opens its own track") no preposition takes.
    static func label(for row: SettingsDiffRow, group: Bool) -> String {
        if group {
            return L("diff.revert.group", "Revert all shortcut changes")
        }
        guard row.changeNote == nil, let old = row.oldValue,
            old != SettingsValueReadout.unset
        else {
            return L("diff.revert.change", "Revert this change")
        }
        return L("diff.revert.to", "Revert (was %1$@)", old)
    }

    /// The row menu's and VoiceOver's action name.
    static var actionName: String { L("diff.revert", "Revert") }
}

/// A draft row's trailing ↺ (#792), beside the row's jump and never
/// inside it, as a live row's Keep is.
struct RowRevertButton: View {
    let row: SettingsDiffRow
    /// Whether the ↺ takes every shortcut change back.
    let group: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SettingsTheme.ink3)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .iconButtonAffordance(DiffRowRevert.label(for: row, group: group))
    }
}

/// The question a group ↺ asks before it takes every shortcut
/// change back (owner, 2026-10-19): what goes, then the one way to
/// let it go.
@MainActor
enum GroupRevertWords {
    static var title: String {
        L("diff.revert.group.title", "Revert all shortcut changes?")
    }

    static var message: String {
        L(
            "diff.revert.group.message",
            "This reverts every shortcut change in this draft, not "
                + "only this one."
        )
    }

    static var confirm: String {
        L("diff.revert.group.confirm", "Revert Shortcuts")
    }
}
