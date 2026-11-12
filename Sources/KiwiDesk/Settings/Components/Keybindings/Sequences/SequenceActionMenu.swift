import KiwiDeskCore
import SwiftUI

/// Opens an end key's action picker, keyed by the node (#843).
struct SequencePickRequest: Identifiable, Equatable {
    let id: UUID
}

/// The one catalogue-backed action picker (#1871, owner 2026-11-09;
/// #3162; #3183 ▸ the action picker): a search field over the whole
/// catalogue in the page's groups, opened on the current pick, with
/// the caller's pinned entries above and "App…" and "Lua…" below the
/// scrolling list — or the pinned entries alone, where the caller
/// offers no catalogue (a gesture's families, a drag's grabs). ↑/↓
/// and real pointer motion move one cursor
/// (`SequenceActionMenu+Cursor`); Return picks it. The trigger is the
/// row's one container: a command or an app on the plain pop-up face,
/// a Lua action's description dashed, which opens the Lua popover
/// instead (`onEditLua`).
struct SequenceActionMenu: View {
    let face: SequencePickFace
    let catalog: SequenceActionCatalog
    /// What VoiceOver calls the trigger.
    let spokenLabel: String
    /// Above the list: "Extend Sequence", or a gesture's families.
    let pins: [SequencePickPin]
    /// Whether the catalogue, App… and Lua… are offered at all.
    var showsCatalogue = true
    let onPick: (NavCommand) -> Void
    let onApp: () -> Void
    let onLua: () -> Void
    /// A click on a Lua key's dashed container.
    let onEditLua: () -> Void

    /// Open while set; the row's "Change action…" sets it too.
    @Binding var request: SequencePickRequest?
    @State var search = ""
    @State var cursor = DropdownCursor<SequencePickSlot>()
    /// Where the list scrolls — set by the keyboard alone, so the
    /// pointer never scrolls the list out from under itself.
    @State var scrollTarget: SequencePickSlot?
    @FocusState private var searchFocused: Bool

    var body: some View {
        trigger
            .accessibilityLabel(spokenLabel)
            .accessibilityValue(title)
            .popover(item: $request) { _ in
                if showsCatalogue {
                    popover.settingsPopoverChrome()
                } else {
                    pinsOnly.settingsPopoverChrome()
                }
            }
            // Every open starts with an empty search (#1357).
            .onChange(of: request) { _, open in
                if open == nil { search = "" } else { opened() }
            }
    }

    @ViewBuilder private var trigger: some View {
        if face.kind == .custom {
            Button(action: onEditLua) {
                Text(title).fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(SequenceDashedStyle())
        } else {
            Button {
                request = SequencePickRequest(id: face.id)
            } label: {
                HStack(spacing: 4) {
                    appIcon
                    Text(title).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .settingsPopUpTrigger()
        }
    }

    /// An app key's icon, as the Apps section's rows draw it.
    @ViewBuilder private var appIcon: some View {
        if let bundleID {
            Image(nsImage: AppIconCache.shared.icon(forBundleID: bundleID))
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
    }

    /// The app an app key opens; nil for every other key.
    private var bundleID: String? {
        guard face.kind == .application else { return nil }
        return KeybindingCatalog.appBundleID(from: face.lua)
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
            ForEach(pins) { pin in
                pinned(
                    .pinned(pin.id),
                    pin.label,
                    symbol: pin.symbol,
                    picked: pin.picked
                )
            }
            Divider()
            list(groups)
            Divider()
            pinned(.app, Self.appLabel, symbol: "app")
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

    /// A pinned-only picker: no search, no catalogue (#3183 ▸ help,
    /// not in-picker hints).
    private var pinsOnly: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(pins) { pin in
                pinned(
                    .pinned(pin.id),
                    pin.label,
                    symbol: pin.symbol,
                    picked: pin.picked
                )
            }
        }
        .padding(10)
        .frame(width: 260)
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
        let picked = face.kind != .custom && command.runs(face.lua)
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
        symbol: String,
        picked: Bool = false
    ) -> some View {
        let onCursor = cursor.highlighted == slot
        return Button {
            take(slot, in: shownGroups)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: picked ? "checkmark" : symbol)
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
        .accessibilityAddTraits(picked ? .isSelected : [])
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

    /// Drawn after a `plus` mark: "+ Extend Sequence" (#3162).
    static var branchLabel: String {
        L("shortcuts.sequence.opens_more", "Extend Sequence")
    }

    static var appLabel: String {
        L("shortcuts.sequence.app", "App…")
    }

    static var luaLabel: String {
        L("shortcuts.sequence.lua", "Lua…")
    }

    /// The action's name, "Lua…" for the user's own, the app's name
    /// for an app key, the face's own words for a family, "Choose…"
    /// for none yet.
    private var title: String {
        if let title = face.title { return title }
        if face.kind == .custom {
            return face.desc.trimmed.isEmpty ? Self.luaLabel : face.desc
        }
        if let bundleID {
            return KeybindingCatalog.displayName(forBundleID: bundleID)
        }
        if let command = catalog.command(running: face.lua) {
            return command.resolvedLabel
        }
        return face.lua.isEmpty
            ? L("shortcuts.sequence.choose", "Choose…") : face.lua
    }
}
