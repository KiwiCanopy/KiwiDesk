import AppKit
import KiwiDeskCore
import SwiftUI

/// App rule row: an app, the scope of its windows that float, and
/// its Space pin (#1022).
///
/// The row was an editable natural-language sentence until #1022
/// (#68 turn 14a); the reversal is argued in
/// `docs/design-decisions.md` ▸ App rules. The Space facet is
/// labelled once by the table header `AppRulesSection` draws
/// above the list, never per row — three rows would otherwise
/// read the same label three times — and the float facet is
/// labelled nowhere, its values being whole predicates.
struct AppRuleRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// Base rules when editing stored profile (#109).
    let overrideBase: [String: SpaceID]?
    let overrideFloatBase: [String]?
    /// Whether the float facet offers title-pattern matching.
    /// Resolved ONCE by the section and handed down: the predicate
    /// has one home, and so must its input — a row re-assembling
    /// `floatRules + overrideFloatBase` could disagree with the
    /// section's `?` about whether the choice exists (architect
    /// review, 2026-09-22).
    let offersTitles: Bool
    /// The area's census gates, assembled once by the section.
    let gates: AppRulesGates
    /// The app whose pattern editor is open, owned by the section
    /// so the row survives losing its last stored rule while it
    /// composes one (#1022, the vanishing-row blocker).
    @Binding var composingTitles: String?
    let onDelete: () -> Void
    /// Target for restoring keyboard focus after deletion (#816).
    @FocusState.Binding var returningRow: String?
    @Environment(\.settingsWidth) private var width

    /// Whether the row is in its stacked form. Read by the facet
    /// controls, which hug their content only where no column
    /// constrains them.
    var stacked: Bool { width.stacksRows }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            facets
            if floatFacet == .titled || editingTitles {
                AppRuleTitledEditor(
                    model: model,
                    app: app,
                    editingTitles: titlesEditing
                )
                .padding(
                    .leading,
                    SettingsMetrics.appRuleIdentityInset
                )
                .opacity(floatInherited ? 0.55 : 1)
            }
        }
    }

    /// `AnyLayout` rather than two subtrees: a reflow must not
    /// tear the menus down — one would close mid-gesture and the
    /// focus this row holds for a deletion would drop. Only the
    /// stacked form's label is conditional, and it is decorative
    /// text with no identity worth keeping.
    private var facets: some View {
        let stacked = self.stacked
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
            // Space FIRST: "this app opens in work" is the
            // headline reason to write a rule at all, and the
            // float facet reads as the qualifier after it.
            facetLabel(
                L("app_rules.space", "Opens in"),
                drawn: stacked
            )
            spaceMenu
                .opacity(spaceInherited ? 0.55 : 1)
                .padding(.leading, facetInset(stacked))
                .frame(
                    width: stacked
                        ? nil : SettingsMetrics.appRuleSpaceColumn,
                    alignment: .leading
                )
            floatMenu
                .opacity(floatInherited ? 0.55 : 1)
                .padding(.leading, facetInset(stacked))
                // The row's focus destination, and the one
                // control every row state keeps enabled: the
                // space menu is inert with no Space to pin to,
                // and a disabled control cannot take the
                // assignment a deletion makes (#1022; #816).
                .focused($returningRow, equals: app)
                .frame(
                    width: stacked
                        ? nil : SettingsMetrics.appRuleFloatColumn,
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
                .padding(.leading, SettingsMetrics.appRuleIdentityInset)
                .accessibilityHidden(true)
        }
    }

    /// Stacked, everything below the identity line hangs under the
    /// app NAME rather than sitting flush left with its icon: five
    /// lines 6 pt apart, inside rows separated by 8 pt and a
    /// divider, read as five rows (ui-designer, 2026-09-22). Wide,
    /// the columns place them and this is 0. A modifier rather
    /// than a nested stack, so the controls stay direct children
    /// of the layout and keep their identity across the reflow.
    private func facetInset(_ stacked: Bool) -> CGFloat {
        stacked ? SettingsMetrics.appRuleIdentityInset : 0
    }

    /// An inherited pin, which the 0.55 dim says is in sync with
    /// the base. A row that NEITHER side pins is not inheriting a
    /// pin — it has none — so it draws at full strength: the old
    /// `!isDraft` term used to keep a freshly added row out of
    /// this branch, and dropping it dimmed every float-only row's
    /// whole pin pair (architect review, 2026-09-22).
    private var spaceInherited: Bool {
        guard let base = overrideBase, base[app] != nil else {
            return false
        }
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

    /// The pattern editor's open state, owned by the SECTION so a
    /// row losing its last stored rule mid-composition is still
    /// listed. It holds no value and only ever names one row.
    var titlesEditing: Binding<Bool> {
        Binding(
            get: { composingTitles == app },
            set: { composingTitles = $0 ? app : nil }
        )
    }

    private var editingTitles: Bool { composingTitles == app }
}
