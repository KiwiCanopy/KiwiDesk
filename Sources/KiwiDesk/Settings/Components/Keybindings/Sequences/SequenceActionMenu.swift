import KiwiDeskCore
import SwiftUI

/// What an end key may run, grouped as the Shortcuts page draws
/// its groups (#1871 ▸ Settings): "Opens more keys ›" first, then
/// the catalogue, then "Lua…" below a divider.
@MainActor
struct SequenceActionCatalog {
    struct Group: Identifiable {
        let title: String
        let commands: [NavCommand]
        var id: String { title }
    }

    let groups: [Group]

    /// The page parts whose rows an end key may run, in page order.
    static let parts: [ShortcutsPagePart] = [
        .showHide, .focus, .moveWindows, .macosDesktops, .layout,
        .sizeFloat, .pocket,
    ]

    init(expander: ShortcutsFamilyRows) {
        groups = Self.parts.compactMap { part in
            guard let title = part.group?.control.text else { return nil }
            let commands = SettingKey.allCases.filter {
                $0.placement.area.flatMap(SettingsDestination.init(area:))
                    == .shortcuts
                    && $0.placement.container.flatMap(
                        ShortcutsPagePart.init
                    ) == part
            }
            .flatMap { expander.rows(for: $0) ?? [] }
            .filter { $0.unavailable == nil }
            return commands.isEmpty
                ? nil : Group(title: title, commands: commands)
        }
    }

    /// The catalogue command `lua` runs, nil for none.
    func command(running lua: String) -> NavCommand? {
        guard !lua.isEmpty else { return nil }
        return groups.lazy.flatMap(\.commands).first { $0.runs(lua) }
    }
}

/// An end key's action pop-up.
struct SequenceActionMenu: View {
    let node: KeyBinding
    let catalog: SequenceActionCatalog
    /// What VoiceOver calls the pop-up.
    let spokenLabel: String
    let onBranch: () -> Void
    let onPick: (NavCommand) -> Void
    let onLua: () -> Void

    var body: some View {
        Menu {
            Button(
                L("shortcuts.sequence.opens_more", "Opens more keys ›"),
                action: onBranch
            )
            Divider()
            ForEach(catalog.groups) { group in
                Section(group.title) {
                    ForEach(group.commands) { command in
                        Button(command.resolvedLabel) { onPick(command) }
                    }
                }
            }
            Divider()
            Button(L("shortcuts.sequence.lua", "Lua…"), action: onLua)
        } label: {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(spokenLabel)
        .accessibilityValue(title)
    }

    /// The action's name, "Lua…" for the user's own, "Choose…" for
    /// none yet.
    private var title: String {
        if node.kind == .custom {
            return node.desc.trimmed.isEmpty
                ? L("shortcuts.sequence.lua", "Lua…") : node.desc
        }
        if let command = catalog.command(running: node.lua) {
            return command.resolvedLabel
        }
        return node.lua.isEmpty
            ? L("shortcuts.sequence.choose", "Choose…") : node.lua
    }
}
