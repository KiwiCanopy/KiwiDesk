import AppKit
import KiwiDeskCore
import SwiftUI

/// App rule row: an app, the scope of its windows that float, and
/// its Space pin (#1022).
///
/// The row was an editable natural-language sentence until #1022
/// (#68 turn 14a); the reversal is argued in
/// `docs/design-decisions.md` ▸ App rules. Its facets are labelled
/// once by the table header `AppRulesSection` draws above the
/// list, never per row — three rows would otherwise read the same
/// two labels six times.
struct AppRuleRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// Base rules when editing stored profile (#109).
    let overrideBase: [String: SpaceID]?
    let overrideFloatBase: [String]?
    let onDelete: () -> Void
    /// Target for restoring keyboard focus after deletion (#816).
    @FocusState.Binding var returningRow: String?
    /// Keeps titled editor visible while patterns are empty.
    @State private var editingTitles = false
    @Environment(\.settingsWidth) private var width

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            facets
            if floatFacet == .titled || editingTitles {
                AppRuleTitledEditor(
                    model: model,
                    app: app,
                    editingTitles: $editingTitles
                )
                .padding(.leading, 28)
                .opacity(floatInherited ? 0.55 : 1)
            }
        }
    }

    /// `AnyLayout` rather than two subtrees: a reflow must not
    /// tear the menus down — one would close mid-gesture and the
    /// focus this row holds for a deletion would drop. Only the
    /// stacked form's labels are conditional, and they are
    /// decorative text with no identity worth keeping.
    private var facets: some View {
        let stacked = width.stacksRows
        let layout =
            stacked
            ? AnyLayout(
                VStackLayout(alignment: .leading, spacing: 6)
            )
            : AnyLayout(
                HStackLayout(
                    alignment: .firstTextBaseline,
                    spacing: 8
                )
            )
        return layout {
            identity(stacked: stacked)
            facetLabel(
                L("app_rules.float", "Float"),
                drawn: stacked
            )
            floatMenu
                .opacity(floatInherited ? 0.55 : 1)
                // The row's focus destination, and the one
                // control every row state keeps enabled: the
                // space menu is disabled on any unpinned row, and
                // a disabled control cannot take the assignment a
                // deletion makes (#1022; #816 is the harm).
                .focused($returningRow, equals: app)
                .frame(
                    width: stacked
                        ? nil : SettingsMetrics.appRuleFloatColumn,
                    alignment: .leading
                )
            facetLabel(
                L("app_rules.pin", "Pin to a Space"),
                drawn: stacked
            )
            pinPair
                .frame(
                    width: stacked
                        ? nil : SettingsMetrics.appRulePinColumn,
                    alignment: .leading
                )
            if !stacked {
                Spacer(minLength: 8)
                deleteButton
            }
        }
        .font(.callout)
    }

    /// The icon and the app's name — and, stacked, the trash,
    /// which has no trailing edge of its own to sit on there.
    @ViewBuilder
    private func identity(stacked: Bool) -> some View {
        HStack(spacing: 6) {
            appIcon
            Text(KeybindingCatalog.displayName(forBundleID: app))
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(
                    width: stacked
                        ? nil : SettingsMetrics.appRuleNameColumn,
                    alignment: .leading
                )
            if stacked {
                Spacer(minLength: 8)
                deleteButton
            }
        }
    }

    /// A facet's label, drawn only in the stacked form — wide, the
    /// table header above the list carries it. Never spoken: each
    /// control names itself, so read aloud this would be the same
    /// words twice (`SettingsRowLabel`'s ruling, applied here).
    @ViewBuilder
    private func facetLabel(
        _ text: String,
        drawn: Bool
    ) -> some View {
        if drawn {
            Text(text)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .accessibilityHidden(true)
        }
    }

    /// The gate and the gated dim as ONE unit: an inherited facet
    /// whose checkbox faded on its own would read as two states.
    private var pinPair: some View {
        HStack(spacing: 6) {
            pinCheckbox
            spaceMenu
        }
        .opacity(spaceInherited ? 0.55 : 1)
    }

    private var spaceInherited: Bool {
        guard let base = overrideBase else { return false }
        return model.config.appRules[app] == base[app]
    }

    private var floatInherited: Bool {
        guard let base = overrideFloatBase else { return false }
        return Set(FloatFacet.rules(base, app: app))
            == Set(
                FloatFacet.rules(
                    model.config.floatRules,
                    app: app
                )
            )
    }

    private var deleteButton: some View {
        Button {
            onDelete()
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .iconButtonAffordance(removeHelp)
        .disabled(
            overrideBase != nil
                && model.config.appRules[app] == nil
                && floatFacet == .never
        )
    }

    private var removeHelp: String {
        overrideBase == nil
            ? L(
                "app_rules.remove_all.help",
                "Remove all rules for this app"
            )
            : L(
                "app_rules.remove_override.help",
                "Remove this profile's effective Space "
                    + "and float rules for this app"
            )
    }

    @ViewBuilder private var appIcon: some View {
        if let url = appURL {
            Image(
                nsImage: NSWorkspace.shared.icon(
                    forFile: url.path
                )
            )
            .resizable()
            .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }

    /// Application bundle URL resolved by bundle identifier.
    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: app
        )
    }

    var floatFacet: FloatFacet {
        FloatFacet.current(
            model.config.floatRules,
            app: app
        )
    }

    var titlesEditing: Binding<Bool> { $editingTitles }
}
