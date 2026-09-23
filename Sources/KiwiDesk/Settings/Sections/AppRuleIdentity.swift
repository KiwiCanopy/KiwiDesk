import KiwiDeskCore
import SwiftUI

/// The app half of an App Rules row — its icon and name — shared
/// by the Space list and the Float list (#1608).
struct AppRuleIdentity: View {
    let app: String
    @Environment(\.settingsWidth) private var width

    var body: some View {
        HStack(spacing: 6) {
            icon
            Text(KeybindingCatalog.displayName(forBundleID: app))
                .fontWeight(.medium)
                .lineLimit(1)
                // A column wide, so both lists' values line up;
                // below the row breakpoint the name hugs instead.
                .frame(
                    width: width.stacksRows
                        ? nil : SettingsMetrics.appRuleNameColumn,
                    alignment: .leading
                )
        }
    }

    private var icon: some View {
        Image(nsImage: AppIconCache.shared.icon(forBundleID: app))
            .resizable()
            .frame(
                width: SettingsMetrics.appRuleIconColumn,
                height: SettingsMetrics.appRuleIconColumn
            )
    }
}

/// The trash at a rule row's trailing edge. Its help names what
/// the ROW removes, so each list hands its own sentence in.
struct AppRuleDeleteButton: View {
    let help: String
    let onDelete: () -> Void

    var body: some View {
        Button {
            onDelete()
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .iconButtonAffordance(help)
    }
}

/// Inline menu label with disclosure chevron
/// (`ProfileEditTargetMenu`), shared by both lists' value menus.
struct AppRuleMenuLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
