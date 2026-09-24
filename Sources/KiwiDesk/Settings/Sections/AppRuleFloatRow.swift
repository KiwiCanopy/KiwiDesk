import KiwiDeskCore
import SwiftUI

/// One row of the "Float" list: an app, and which of its windows
/// float (#1608). A title pattern's editor opens under THIS row,
/// so its scope sits under the one thing it governs.
struct AppRuleFloatRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// Whether the section draws the "Applies to" column (#1393).
    let showsReach: Bool
    /// Whether the scope menu offers title matching, resolved ONCE
    /// by the section: the predicate has one home, and so must its
    /// input (`AppRuleTitleOfferWiringTests`).
    let offersTitles: Bool
    /// The app whose pattern editor is open, owned by the section
    /// so the row survives having no stored rule while it composes
    /// its first pattern (#1022).
    @Binding var composingTitles: String?
    let onDelete: (RuleRemoval) -> Void
    /// Target for restoring keyboard focus after deletion (#816).
    @FocusState.Binding var returningRow: String?
    @Environment(\.settingsWidth) private var width

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(
                alignment: .firstTextBaseline,
                spacing: SettingsMetrics.appRuleColumnSpacing
            ) {
                AppRuleIdentity(app: app)
                floatMenu
                    // The row's focus destination (#816).
                    .focused($returningRow, equals: app)
                if showsReach, let reading {
                    RuleReachControl(
                        model: model,
                        family: .float,
                        app: app,
                        subject: KeybindingCatalog.displayName(
                            forBundleID: app
                        ),
                        reading: reading,
                        value: floatLabel
                    )
                }
                Spacer(minLength: SettingsMetrics.appRuleColumnSpacing)
                AppRuleDeleteButton(
                    help: removeHelp,
                    sharedFrom: sharedFrom,
                    onDelete: onDelete
                )
                .disabled(scope == .never && !editingTitles)
            }
            .font(.callout)
            if scope == .titled || editingTitles {
                AppRuleTitledEditor(
                    model: model,
                    app: app,
                    editingTitles: titlesEditing
                )
                .padding(.leading, editorInset)
            }
        }
    }

    /// The pattern editor hangs under the VALUE it qualifies, not
    /// the whole row; stacked, where no column places the value,
    /// under the app name.
    private var editorInset: CGFloat {
        width.stacksRows
            ? SettingsMetrics.appRuleIdentityInset
            : SettingsMetrics.appRuleIdentityColumn
                + SettingsMetrics.appRuleColumnSpacing
    }

    /// Two scopes and no "tiles" value: a row in this list floats,
    /// and the way to stop floating an app is the trash. The dash
    /// is a row whose last rule has just gone, for the frame the
    /// list still draws it.
    private var floatMenu: some View {
        Menu {
            Button(allLabel) { setAll() }
            if offersTitles {
                Button(titledLabel) { openTitles() }
            }
        } label: {
            AppRuleMenuLabel(text: floatLabel)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .accessibilityLabel(L("app_rules.float", "Float"))
        .accessibilityValue(floatFacetLabel)
    }

    private var allLabel: String {
        L("app_rules.float.scope.all", "All windows")
    }

    private var titledLabel: String {
        L("app_rules.float.scope.titled", "Windows titled…")
    }

    /// The resting VALUE drops the menu item's ellipsis, which
    /// promises further UI — right on the choice, wrong at rest.
    private var restingTitledLabel: String {
        L("app_rules.float.scope.titled.resting", "Windows titled")
    }

    /// An open pattern editor reads as the titled value whatever
    /// the store holds, because that is the rule being composed.
    var floatLabel: String {
        if editingTitles { return restingTitledLabel }
        switch scope {
        case .never: return L("app_rules.dash", "—")
        case .all: return allLabel
        case .titled: return restingTitledLabel
        }
    }

    /// The SPOKEN value. A dash reads as nothing aloud, so only
    /// the empty row differs from the drawn cell.
    var floatFacetLabel: String {
        scope == .never && !editingTitles
            ? L("app_rules.float.none", "Does not float")
            : floatLabel
    }

    var scope: FloatFacet {
        FloatFacet.current(model.config.floatRules, app: app)
    }

    private var reading: RuleReachReading? {
        model.floatReach(app, describe: SettingsModel.floatWords)
    }

    /// The edited profile, where the trash must ask: another
    /// profile uses this rule too.
    private var sharedFrom: String? {
        guard showsReach, let reading, reading.users.count > 1
        else { return nil }
        return reading.editing
    }

    private var removeHelp: String {
        L("app_rules.float.remove.help", "Stop floating this app")
    }

    var titlesEditing: Binding<Bool> {
        Binding(
            get: { composingTitles == app },
            set: { composingTitles = $0 ? app : nil }
        )
    }

    private var editingTitles: Bool { composingTitles == app }

    // MARK: - Mutations (GUI assembles the colon syntax)

    /// Opens the pattern editor WITHOUT clearing the float rule:
    /// a bare rule may be the row's only stored rule, and
    /// `AppRuleTitledEditor.addPattern` drops it as the first
    /// pattern lands (#1022).
    private func openTitles() {
        titlesEditing.wrappedValue = true
    }

    private func setAll() {
        titlesEditing.wrappedValue = false
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
        model.config.floatRules.append(app)
    }
}
