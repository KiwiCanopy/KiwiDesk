import AppKit
import KiwiDeskCore
import SwiftUI

/// Searchable app picker button and popover (#263, `IconPicker`,
/// `AppSelector`, `appMenu`, `AppRef`, `AppIconCache`, `InstalledApp`).
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
    @FocusState private var searchFocused: Bool

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 4) {
                Text(selection ?? placeholder)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: minWidth, alignment: .leading)
        }
        .settingsActionButton()
        .controlSize(.large)
        .onAppear {
            AppIconCache.shared.warm()
            Task.detached {
                _ = KeybindingCatalog.diskAppIconPaths
            }
        }
        .popover(isPresented: $showing) {
            if let guessed {
                guessedPopover(guessed())
            } else {
                popover
            }
        }
        // Every open starts with an empty search (#1357): the
        // reset rides the popover's own dismissal edge, and the
        // on-screen apps are read at the opening one.
        .onChange(of: showing) { _, isShowing in
            if !isShowing { search = "" }
            if isShowing { onScreenApps = onScreen?() ?? [] }
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
            .onSubmit { pickFirst(lists) }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionsBody(lists)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            escapeRow
        }
        .padding(12)
        .frame(width: 280, height: 360)
        .onAppear { searchFocused = true }
    }

    private var sections: (onScreen: [OnScreenApp], all: [InstalledApp]) {
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
                    AppPickerRow(
                        name: app.name,
                        bundleID: app.bundleID
                    ) {
                        pick(.init(bundleID: app.key, name: app.name))
                    }
                }
            }
        }
        if !lists.all.isEmpty {
            section(Self.allTitle, headed: both) {
                ForEach(lists.all) { app in
                    AppPickerRow(name: app.name, bundleID: app.bundleID) {
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

    private func pick(_ app: InstalledApp) {
        onPick(app)
        showing = false
    }

    /// Return picks the first row the search left.
    private func pickFirst(
        _ lists: (onScreen: [OnScreenApp], all: [InstalledApp])
    ) {
        if let first = lists.onScreen.first {
            pick(.init(bundleID: first.key, name: first.name))
        } else if let first = lists.all.first {
            pick(first)
        }
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
                }
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
        Button {
            showing = false
            DispatchQueue.main.async { onEscape() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis.circle")
                    .frame(width: AppIconCache.side)
                Text(escapeLabel)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .rowHoverHighlight()
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
