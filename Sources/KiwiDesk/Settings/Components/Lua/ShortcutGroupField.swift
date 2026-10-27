import KiwiDeskCore
import SwiftUI

/// A Lua binding's shortcut group (#2544 ▸ Ruling): a field taking
/// any name, beside a menu of the built-in groups, the user's own
/// and Custom. Typed text is stored on Return or when the field
/// loses focus; Escape puts the stored group back.
struct ShortcutGroupField: View {
    @Binding var group: String
    /// The groups bindings make of their own, in KiwiHub's order.
    let inUse: () -> [String]
    /// The binding's name for VoiceOver.
    let rowName: String

    @State private var text = ""
    /// New group… emptied the field; an empty commit keeps the group.
    @State private var startedNew = false
    @FocusState private var editing: Bool

    private var naming: ShortcutGroupNaming { .current }

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .commitsOnSave($editing, commit)
                .onExitCommand(perform: revert)
                .accessibilityLabel(axLabel)
            NativePullDown(header: builtInHeader, items: menuItems) {
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .help(axLabel)
            .accessibilityLabel(axLabel)
            .accessibilityValue(spokenGroup)
        }
        .frame(width: 170)
        .onAppear(perform: revert)
        .onChange(of: group) { _, _ in
            if !editing { revert() }
        }
    }

    private func commit() {
        let stored = naming.committed(
            text,
            over: group,
            startedNew: startedNew
        )
        startedNew = false
        if stored != group { group = stored }
        text = naming.shown(stored)
    }

    private func revert() {
        startedNew = false
        text = naming.shown(group)
    }

    private func pick(_ stored: String) {
        group = stored
        text = naming.shown(stored)
    }

    private func menuItems() -> [PullDownItem] {
        ShortcutGroupMenu.entries(group: group, inUse: inUse()).map {
            entry in
            switch entry {
            case .builtIn(let builtIn, let checked):
                return PullDownItem(title: builtIn.title, checked: checked) {
                    pick(builtIn.rawValue)
                }
            case .ownHeader:
                return .header(ownHeader)
            case .own(let name, let checked):
                return PullDownItem(title: name, checked: checked) {
                    pick(name)
                }
            case .divider:
                return .divider
            case .custom(let checked):
                return PullDownItem(title: customTitle, checked: checked) {
                    pick("")
                }
            case .newGroup:
                return PullDownItem(title: newGroupTitle) {
                    startedNew = true
                    text = ""
                    editing = true
                }
            }
        }
    }

    /// While a new group is named the empty field must not read as
    /// Custom, which it does not mean (#2688).
    private var placeholder: String {
        startedNew
            ? L("shortcuts.group.name_placeholder", "Group name")
            : customTitle
    }

    private var customTitle: String {
        L("shortcuts.panel.custom", "Custom")
    }

    private var builtInHeader: String {
        L("shortcuts.group.built_in", "Built-in shortcut groups")
    }

    private var ownHeader: String {
        L("shortcuts.group.own", "Your shortcut groups")
    }

    private var newGroupTitle: String {
        L("shortcuts.group.new", "New shortcut group…")
    }

    /// The label replaced the menu's own announcement, so the
    /// current group is given back (gui.md, #812).
    private var spokenGroup: String { naming.shown(group) }

    private var axLabel: String {
        L("shortcuts.group.ax", "Shortcut group for %1$@", rowName)
    }
}

/// The shortcut group menu under the "Built-in" header (#2544 ▸
/// Ruling): the built-in groups in KiwiHub's order, the user's own
/// under a header of their own while there are any, then Custom
/// and New group. The current group is checked.
enum ShortcutGroupMenu: Equatable {
    case builtIn(ShortcutGroup, checked: Bool)
    case ownHeader
    case own(String, checked: Bool)
    case divider
    case custom(checked: Bool)
    case newGroup

    static func entries(group: String, inUse: [String]) -> [Self] {
        let current = ShortcutGroup.filing(group)
        var entries = ShortcutGroup.allCases.map {
            Self.builtIn($0, checked: current == .builtIn($0))
        }
        if !inUse.isEmpty {
            entries.append(.ownHeader)
            entries += inUse.map {
                .own($0, checked: current == .own($0))
            }
        }
        return entries + [
            .divider, .custom(checked: current == .none), .newGroup,
        ]
    }
}
