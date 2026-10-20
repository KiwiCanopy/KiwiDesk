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
    /// A live row's revert (#2411), answering whether every leaf
    /// went back, so the row left the list.
    let performLive: (SettingsDiffRow) -> Bool
    /// The names of the other bindings a binding row's ↺ takes
    /// back, read from the walk the revert runs (#2412).
    let companions: (SettingsDiffRow) -> [String]

    init(model: SettingsModel, alwaysVisible: Bool) {
        self.alwaysVisible = alwaysVisible
        can = { [weak model] in model?.canRevert($0) ?? false }
        takesGroup = { [weak model] in
            model?.revertTakesGroup($0) ?? false
        }
        perform = { [weak model] in model?.revert($0) }
        performLive = { [weak model] row in
            model?.revertLive(row.keepIDs)?.refused.isEmpty ?? false
        }
        companions = { [weak model] in model?.revertCompanions($0) ?? [] }
    }

    /// The ↺'s words: what it takes back — every shortcut change
    /// for a group, else the value it returns to, where the row
    /// states one. A label rather than a sentence, since a value
    /// may be a clause ("Opens its own track") no preposition takes.
    static func label(
        for row: SettingsDiffRow,
        group: Bool,
        with others: [String] = []
    ) -> String {
        if group {
            return GroupRevertWords.button(for: row)
        }
        // A binding takes the bindings that took its chords (#2412).
        if others.count == 1, let other = others.first {
            return L("diff.revert.with_one", "Revert, with %1$@", other)
        }
        if others.count > 1 {
            return L(
                "diff.revert.with_count",
                "Revert, with other shortcuts: %1$d",
                others.count
            )
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
    /// Whether the ↺ takes more than its row, and so asks.
    let group: Bool
    /// The other rows' labels a binding's ↺ takes with it (#2412).
    var others: [String] = []
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SettingsTheme.ink3)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .iconButtonAffordance(
            DiffRowRevert.label(for: row, group: group, with: others)
        )
    }
}

/// The question a ↺ asks before it takes more than its row: every
/// shortcut change (owner, 2026-10-19), or a whole layer or lens
/// (#2412) — what goes, then the one way to let it go.
@MainActor
enum GroupRevertWords {
    /// The layer or lens a row's ↺ puts back, by the name it shows.
    private static func subject(
        _ row: SettingsDiffRow
    ) -> (layer: Bool, name: String)? {
        switch row.revert {
        case .layer(let stored, let page):
            (page ?? stored).map { (true, $0) }
        case .lens(let stored, let page):
            (page ?? stored).map { (false, $0) }
        default:
            nil
        }
    }

    static func button(for row: SettingsDiffRow) -> String {
        switch subject(row) {
        case (true, let name)?:
            L("diff.revert.layer", "Revert the “%1$@” layer", name)
        case (false, let name)?:
            L("diff.revert.lens", "Revert the “%1$@” lens", name)
        case nil:
            L("diff.revert.group", "Revert all shortcut changes")
        }
    }

    static func title(for row: SettingsDiffRow) -> String {
        switch subject(row) {
        case (true, let name)?:
            L("diff.revert.layer.title", "Revert the “%1$@” layer?", name)
        case (false, let name)?:
            L("diff.revert.lens.title", "Revert the “%1$@” lens?", name)
        case nil:
            L("diff.revert.group.title", "Revert all shortcut changes?")
        }
    }

    static func message(for row: SettingsDiffRow) -> String {
        switch subject(row) {
        case (true, _)?:
            L(
                "diff.revert.layer.message",
                "This puts the layer back as it was saved, with its "
                    + "shortcuts."
            )
        case (false, _)?:
            L(
                "diff.revert.lens.message",
                "This puts the lens back as it was saved, with its "
                    + "shortcut."
            )
        case nil:
            L(
                "diff.revert.group.message",
                "This reverts every shortcut change in this draft, not "
                    + "only this one."
            )
        }
    }

    static func confirm(for row: SettingsDiffRow) -> String {
        switch subject(row) {
        case (true, _)?: L("diff.revert.layer.confirm", "Revert Layer")
        case (false, _)?: L("diff.revert.lens.confirm", "Revert Lens")
        case nil: L("diff.revert.group.confirm", "Revert Shortcuts")
        }
    }
}
