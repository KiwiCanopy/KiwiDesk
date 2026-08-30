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

    @State private var showing = false
    @State private var search = ""

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
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { app in
                        row(app)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
        }
        .padding(12)
        .frame(width: 280, height: 360)
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
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .rowHoverHighlight()
    }

    private var filtered: [KeybindingCatalog.InstalledApp] {
        AppPickerFilter.matching(
            KeybindingCatalog.installedAppsSnapshot.filter {
                !exclude.contains($0.bundleID)
            },
            query: search
        )
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
