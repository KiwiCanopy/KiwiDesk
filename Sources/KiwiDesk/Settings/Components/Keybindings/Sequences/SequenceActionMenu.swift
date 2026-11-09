import KiwiDeskCore
import SwiftUI

/// Opens an end key's action picker, keyed by the node (#843).
struct SequencePickRequest: Identifiable, Equatable {
    let id: UUID
}

/// A row the action picker's one cursor stops on (`DropdownCursor`):
/// "Opens more keys ›" pinned above the list, a catalogue command,
/// or "Lua…" pinned below it.
enum SequencePickSlot: Hashable {
    case branch
    case command(String)
    case lua
}

/// An end key's action picker (#1871, owner 2026-11-09): a search
/// field over the whole catalogue in the page's groups, opened on
/// the current pick, with "Opens more keys ›" and "Lua…" pinned
/// outside the scrolling list. ↑/↓ and real pointer motion move one
/// cursor (`SequenceActionMenu+Cursor`); Return picks it.
struct SequenceActionMenu: View {
    let node: KeyBinding
    let catalog: SequenceActionCatalog
    /// What VoiceOver calls the trigger.
    let spokenLabel: String
    let onBranch: () -> Void
    let onPick: (NavCommand) -> Void
    let onLua: () -> Void

    @State var request: SequencePickRequest?
    @State var search = ""
    @State var cursor = DropdownCursor<SequencePickSlot>()
    /// Where the list scrolls — set by the keyboard alone, so the
    /// pointer never scrolls the list out from under itself.
    @State var scrollTarget: SequencePickSlot?
    @FocusState private var searchFocused: Bool

    var body: some View {
        Button {
            request = SequencePickRequest(id: node.id)
        } label: {
            HStack(spacing: 4) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .settingsPopUpTrigger()
        .accessibilityLabel(spokenLabel)
        .accessibilityValue(title)
        .popover(item: $request) { _ in
            popover.settingsPopoverChrome()
        }
        // Every open starts with an empty search (#1357).
        .onChange(of: request) { _, open in
            if open == nil { search = "" } else { opened() }
        }
    }

    private var popover: some View {
        let groups = shownGroups
        return VStack(spacing: 6) {
            TextField(
                L("shortcuts.sequence.search", "Search actions"),
                text: $search
            )
            .textFieldStyle(.roundedBorder)
            .focused($searchFocused)
            .onSubmit { commit(groups) }
            .onKeyPress(.downArrow) { move(1, in: groups) }
            .onKeyPress(.upArrow) { move(-1, in: groups) }
            .onChange(of: search) { _, _ in searched() }
            pinned(.branch, Self.branchLabel, symbol: "chevron.right")
            Divider()
            list(groups)
            Divider()
            pinned(
                .lua,
                Self.luaLabel,
                symbol: "chevron.left.forwardslash.chevron.right"
            )
        }
        .padding(12)
        .frame(width: 280, height: 360)
        .onAppear { searchFocused = true }
    }

    @ViewBuilder private func list(
        _ groups: [SequenceActionCatalog.Group]
    ) -> some View {
        if groups.isEmpty {
            Text(
                L(
                    "shortcuts.sequence.no_match",
                    "No action matches \u{201C}%1$@\u{201D}",
                    search.trimmed
                )
            )
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink3)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
            .padding(.top, 8)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groups) { group in
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SettingsTheme.ink3)
                                .padding(.top, 6)
                                .padding(.bottom, 2)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(group.commands) { command in
                                row(command)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // A row's scroll id is its command's Lua, the ForEach's.
                .onChange(of: scrollTarget) { _, slot in
                    guard case .command(let lua) = slot else { return }
                    proxy.scrollTo(lua, anchor: .center)
                }
                // Opened scrolled to the current pick.
                .onAppear {
                    if case .command(let lua) = scrollTarget {
                        proxy.scrollTo(lua, anchor: .center)
                    }
                }
            }
        }
    }

    private func row(_ command: NavCommand) -> some View {
        let slot = SequencePickSlot.command(command.lua)
        let onCursor = cursor.highlighted == slot
        let picked = node.kind != .custom && command.runs(node.lua)
        return Button {
            pick(command)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .opacity(picked ? 1 : 0)
                    .frame(width: 12)
                    .accessibilityHidden(true)
                Text(bolded(command.resolvedLabel)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(DropdownRowStyle.ink(onCursor))
            .contentShape(Rectangle())
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .dropdownCursorRow(onCursor) { hover(slot) }
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private func pinned(
        _ slot: SequencePickSlot,
        _ label: String,
        symbol: String
    ) -> some View {
        let onCursor = cursor.highlighted == slot
        return Button {
            take(slot, in: shownGroups)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .frame(width: 12)
                    .accessibilityHidden(true)
                Text(label)
                Spacer(minLength: 0)
            }
            .foregroundStyle(DropdownRowStyle.ink(onCursor))
            .contentShape(Rectangle())
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .dropdownCursorRow(onCursor) { hover(slot) }
    }

    /// `label` with the query's match in bold, as the Shortcuts
    /// side draws a hit.
    private func bolded(_ label: String) -> AttributedString {
        var text = AttributedString(label)
        guard
            let range = ShortcutsSheet.matchRange(
                of: search.trimmed,
                in: label
            ),
            let lower = AttributedString.Index(range.lowerBound, within: text),
            let upper = AttributedString.Index(range.upperBound, within: text)
        else { return text }
        text[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        return text
    }

    static var branchLabel: String {
        L("shortcuts.sequence.opens_more", "Opens more keys ›")
    }

    static var luaLabel: String {
        L("shortcuts.sequence.lua", "Lua…")
    }

    /// The action's name, "Lua…" for the user's own, "Choose…" for
    /// none yet.
    private var title: String {
        if node.kind == .custom {
            return node.desc.trimmed.isEmpty ? Self.luaLabel : node.desc
        }
        if let command = catalog.command(running: node.lua) {
            return command.resolvedLabel
        }
        return node.lua.isEmpty
            ? L("shortcuts.sequence.choose", "Choose…") : node.lua
    }
}
