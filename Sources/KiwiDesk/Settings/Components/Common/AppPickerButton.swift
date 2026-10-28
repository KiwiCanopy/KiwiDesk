import AppKit
import KiwiDeskCore
import SwiftUI

/// Searchable app picker button and popover (#263, `IconPicker`,
/// `AppSelector`, `appMenu`, `AppRef`, `AppIconCache`, `InstalledApp`).
/// ↑/↓ and real pointer motion move one cursor over the rows and
/// the escape (`DropdownCursor`, `AppPickerButton+Cursor`); Return
/// picks it.
struct AppPickerButton: View {
    /// Shown on the trigger when nothing is chosen yet.
    let placeholder: String
    /// The current selection's display name, or nil for none.
    let selection: String?
    var minWidth: CGFloat = 110
    let onPick: (KeybindingCatalog.InstalledApp) -> Void
    let escapeLabel: String
    let onEscape: () -> Void
    /// Bundle IDs to omit from the picker list (#334).
    var exclude: Set<String> = []
    /// Where given, the list is these apps instead of every
    /// installed one, read when the popover opens (#2071).
    var guessed: (() -> [GuessedFloatApp])?
    /// Where given, the apps on screen lead the list as their own
    /// section, read when the popover opens (#2103 ruling 27).
    var onScreen: (() -> [OnScreenApp])?

    @State private var showing = false
    @State private var search = ""
    @State private var onScreenApps: [OnScreenApp] = []
    @State var cursor = DropdownCursor<AppPickerSlot>()
    /// Where the list scrolls — set by the keyboard alone, so the
    /// pointer never scrolls the list out from under itself.
    @State var scrollTarget: AppPickerSlot?
    @FocusState private var searchFocused: Bool

    var body: some View {
        Button {
            showing = true
        } label: {
            // The chevron trails at the capsule's end, as a native
            // pop-up's does, whatever the 110 pt floor leaves (#268).
            HStack(spacing: 4) {
                Text(selection ?? placeholder)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: minWidth, alignment: .leading)
            // The spacer fills the floor and no further: never greedy
            // where a call site does not hug (#2396).
            .fixedSize(horizontal: true, vertical: false)
        }
        .settingsPopUpTrigger()
        .controlSize(.large)
        .onAppear {
            AppIconCache.shared.warm()
            Task.detached {
                _ = KeybindingCatalog.diskAppIconPaths
            }
        }
        .popover(isPresented: $showing) {
            Group {
                if let guessed {
                    guessedPopover(guessed())
                } else {
                    popover
                }
            }
            .settingsPopoverChrome()
        }
        // Every open starts with an empty search (#1357): the
        // reset rides the popover's own dismissal edge, and the
        // on-screen apps are read at the opening one.
        .onChange(of: showing) { _, isShowing in
            if !isShowing { search = "" }
            if isShowing {
                onScreenApps = onScreen?() ?? []
                opened()
            }
        }
    }

    // MARK: - Popover

    /// The search, the sections, then the one escape pinned below
    /// them — the same order in every picker (#2103 ruling 27).
    private var popover: some View {
        let lists = sections
        return VStack(spacing: 8) {
            TextField(
                L("app_picker.search.placeholder", "Search apps"),
                text: $search
            )
            .textFieldStyle(.roundedBorder)
            .focused($searchFocused)
            .onSubmit { commit(lists) }
            .onKeyPress(.downArrow) { move(1, in: lists) }
            .onKeyPress(.upArrow) { move(-1, in: lists) }
            .onChange(of: search) { _, _ in searched() }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionsBody(lists)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: scrollTarget) { _, slot in
                    guard let id = slot?.rowID else { return }
                    proxy.scrollTo(id)
                }
            }
            Divider()
            escapeRow
        }
        .padding(12)
        .frame(width: 280, height: 360)
        .onAppear { searchFocused = true }
    }

    var sections: (onScreen: [OnScreenApp], all: [InstalledApp]) {
        AppPickerSections.lists(
            onScreen: onScreenApps,
            installed: KeybindingCatalog.installedAppsSnapshot,
            exclude: exclude,
            query: search
        )
    }

    typealias InstalledApp = KeybindingCatalog.InstalledApp

    @ViewBuilder private func sectionsBody(
        _ lists: (onScreen: [OnScreenApp], all: [InstalledApp])
    ) -> some View {
        let both = !lists.onScreen.isEmpty && !lists.all.isEmpty
        if lists.onScreen.isEmpty, lists.all.isEmpty {
            Text(
                L("app_picker.no_match", "No matching apps.")
            )
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink3)
            .padding(.vertical, 6)
        }
        if !lists.onScreen.isEmpty {
            section(Self.onScreenTitle, headed: both) {
                ForEach(lists.onScreen, id: \.key) { app in
                    let slot = AppPickerSlot.onScreen(app.key)
                    AppPickerRow(
                        name: app.name,
                        bundleID: app.bundleID,
                        onCursor: cursor.highlighted == slot,
                        onPoint: { hover(slot) }
                    ) {
                        pick(.init(bundleID: app.key, name: app.name))
                    }
                }
            }
        }
        if !lists.all.isEmpty {
            section(Self.allTitle, headed: both) {
                ForEach(lists.all) { app in
                    let slot = AppPickerSlot.installed(app.bundleID)
                    AppPickerRow(
                        name: app.name,
                        bundleID: app.bundleID,
                        onCursor: cursor.highlighted == slot,
                        onPoint: { hover(slot) }
                    ) {
                        pick(app)
                    }
                }
            }
        }
    }

    @ViewBuilder private func section<Rows: View>(
        _ title: String,
        headed: Bool,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if headed {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
            }
            rows()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(headed ? title : "")
    }

    static var onScreenTitle: String {
        L("app_picker.section.on_screen", "On screen now")
    }

    static var allTitle: String {
        L("app_picker.section.all", "All apps")
    }

    func pick(_ app: InstalledApp) {
        onPick(app)
        showing = false
    }

    /// The Tile picker's list (#2071): no search over a short list,
    /// the hint saying where the rows come from, and the escape
    /// last, as in every picker.
    private func guessedPopover(_ apps: [GuessedFloatApp]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GuessedAppRows(
                apps: apps.filter { !exclude.contains($0.bundleID) },
                onPick: { app in
                    onPick(app)
                    showing = false
                },
                cursor: cursor.highlighted.flatMap(\.installedID),
                onPoint: { hover(.installed($0)) }
            )
            Divider()
            Text(GuessedAppRows.hint)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            escapeRow
        }
        .padding(12)
        .frame(width: 280)
    }

    private var escapeRow: some View {
        let onCursor = cursor.highlighted == .escape
        return Button(action: escape) {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis.circle")
                    .frame(width: AppIconCache.side)
                Text(escapeLabel)
                Spacer()
            }
            .foregroundStyle(DropdownRowStyle.ink(onCursor))
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .dropdownCursorRow(onCursor) { hover(.escape) }
    }

    func escape() {
        showing = false
        DispatchQueue.main.async { onEscape() }
    }
}

/// Pure substring filter matching localized name or bundle id via
/// `searchMatches`.
enum AppPickerFilter {
    static func matching(
        _ apps: [KeybindingCatalog.InstalledApp],
        query: String
    ) -> [KeybindingCatalog.InstalledApp] {
        let query = query.trimmed
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.searchMatches(query)
                || $0.bundleID.searchMatches(query)
        }
    }
}
