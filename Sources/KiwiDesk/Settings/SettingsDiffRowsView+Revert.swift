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
    let perform: (SettingsDiffRow) -> Void

    init(model: SettingsModel, alwaysVisible: Bool) {
        self.alwaysVisible = alwaysVisible
        can = { [weak model] in model?.canRevert($0) ?? false }
        perform = { [weak model] in model?.revert($0) }
    }

    /// The ↺'s words: the value it returns to, where the row
    /// states one.
    static func label(for row: SettingsDiffRow) -> String {
        guard row.changeNote == nil, let old = row.oldValue else {
            return L("diff.revert.change", "Revert this change")
        }
        return L("diff.revert.to", "Revert to %1$@", old)
    }

    /// The row menu's and VoiceOver's action name.
    static var actionName: String { L("diff.revert", "Revert") }
}

/// A draft row's trailing ↺ (#792), beside the row's jump and never
/// inside it, as a live row's Keep is.
struct RowRevertButton: View {
    let row: SettingsDiffRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SettingsTheme.ink3)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .iconButtonAffordance(DiffRowRevert.label(for: row))
    }
}
