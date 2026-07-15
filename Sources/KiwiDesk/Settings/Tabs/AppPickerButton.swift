import AppKit
import KiwiDeskCore
import SwiftUI

/// The searchable app picker (#263), the sibling of
/// `IconPicker` for the two app choosers (`AppSelector` in App
/// Rules, `appMenu` in Open Applications). A native `Menu` over
/// 150–300 installed apps only offers prefix type-to-select; a
/// popover with a substring search over a lazy icon list is the
/// macOS move for long app lists. The persistent escape row
/// beneath the search (Custom… / Other…) survives filtering.
///
/// Apps are identified by lower-cased bundle id and shown by
/// localized name (see `AppRef`); the caller stores the id the
/// `onPick` app carries. Icons come from the `@MainActor`
/// `AppIconCache`, not off `InstalledApp`.
struct AppPickerButton: View {
    /// Shown on the trigger when nothing is chosen yet.
    let placeholder: String
    /// The current selection's display name, or nil for none.
    let selection: String?
    /// Trigger width, so pickers line up with their neighbors.
    var minWidth: CGFloat = 150
    let onPick: (KeybindingCatalog.InstalledApp) -> Void
    /// The persistent escape row: its label (Custom… / Other…)
    /// and the action it triggers (reveal a field / open a
    /// panel). Runs after the popover dismisses.
    let escapeLabel: String
    let onEscape: () -> Void

    @State private var showing = false
    @State private var search = ""
    /// A snapshot taken on appear — the running-app set is
    /// frozen for this picker's lifetime (#263), replacing the
    /// per-render `installedApps` re-query.
    @State private var apps: [KeybindingCatalog.InstalledApp] = []

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 4) {
                Text(selection ?? placeholder)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: minWidth, alignment: .leading)
        }
        .controlSize(.large)
        .onAppear {
            if apps.isEmpty {
                apps = KeybindingCatalog.installedApps
            }
            AppIconCache.shared.warm()
        }
        .popover(isPresented: $showing) { popover }
    }

    // MARK: - Popover

    private var popover: some View {
        VStack(spacing: 8) {
            TextField(
                L("app_picker.search.placeholder", "Search apps"),
                text: $search
            )
            .textFieldStyle(.roundedBorder)
            escapeRow
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { app in
                        row(app)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280, height: 360)
    }

    /// The escape hatch, kept above the list so it never scrolls
    /// out of reach and survives filtering.
    private var escapeRow: some View {
        Button {
            showing = false
            onEscape()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis.circle")
                    .frame(width: AppIconCache.side)
                Text(escapeLabel)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }

    private func row(
        _ app: KeybindingCatalog.InstalledApp
    ) -> some View {
        Button {
            onPick(app)
            showing = false
        } label: {
            HStack(spacing: 8) {
                Image(
                    nsImage: AppIconCache.shared.icon(
                        forBundleID: app.bundleID
                    )
                )
                .resizable()
                .frame(
                    width: AppIconCache.side,
                    height: AppIconCache.side
                )
                Text(app.name)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }

    private var filtered: [KeybindingCatalog.InstalledApp] {
        AppPickerFilter.matching(apps, query: search)
    }
}

/// The picker's substring filter, split out pure so it is unit
/// testable without the view. Case-insensitive on the localized
/// name; an empty (or whitespace) query keeps every app.
enum AppPickerFilter {
    static func matching(
        _ apps: [KeybindingCatalog.InstalledApp],
        query: String
    ) -> [KeybindingCatalog.InstalledApp] {
        let query = query.trimmed
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}
