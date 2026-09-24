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
/// the ROW removes, so each list hands its own sentence in. Where
/// other profiles share the rule it asks where the removal goes
/// (#1393): the edited profile, or every profile holding it.
struct AppRuleDeleteButton: View {
    let help: String
    /// The edited profile, when others share the rule.
    var sharedFrom: String?
    let onDelete: (RuleRemoval) -> Void

    @ViewBuilder var body: some View {
        if let sharedFrom {
            Menu {
                Button(
                    L("app_rules.remove.here", "Remove from %1$@", sharedFrom)
                ) { onDelete(.here) }
                Button(
                    L(
                        "app_rules.remove.everywhere",
                        "Remove from every profile"
                    )
                ) { onDelete(.everywhere) }
            } label: {
                // The icon ink, which the neutral menu label's own
                // ink would otherwise outrank (#1393).
                Image(systemName: "trash")
                    .foregroundStyle(SettingsTheme.ink2)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .neutralMenuLabel()
            .fixedSize()
            .iconHoverChip()
            .help(help)
            .accessibilityLabel(help)
            .accessibilityValue(sharedFrom)
        } else {
            Button {
                onDelete(.everywhere)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(help)
        }
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
