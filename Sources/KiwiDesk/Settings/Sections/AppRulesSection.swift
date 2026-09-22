import KiwiDeskCore
import SwiftUI

/// Whole App ▸ App Rules settings section (#68 §3.11, #1022).
struct AppRulesSection: View {
    @ObservedObject var model: SettingsModel
    /// Restores keyboard focus after deleting a rule row (#816).
    @FocusState private var returningRow: String?
    /// The app whose pattern editor is open. Owned here, not by
    /// the row, because a float-only row clears its ONLY stored
    /// rule while composing a titled one and `apps` is derived
    /// from the store — without this the ForEach dropped the row
    /// mid-gesture (#1022, architect + ui-designer review). It is
    /// not a re-admitted `draftApps`: it names at most one row,
    /// only while that row's editor is open, and holds no value.
    @State private var composingTitles: String?
    @State private var newSpaceApp = ""
    @State private var newFloatingApp = ""
    @Environment(\.settingsWidth) private var width

    /// Base rules when editing stored profile (#109); nil during live editing.
    var overrideBase: [String: SpaceID]? {
        model.profileEditingBaseAppRules
    }

    private var overrideFloatBase: [String]? {
        model.profileEditingBaseFloatRules
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection(
                    SettingsCatalog.appRules.rulesPerApp,
                    caption: rulesCaption,
                    help: sectionHelp
                ) {
                    overrideIndicator
                    if apps.isEmpty {
                        emptyNote
                    } else {
                        tableHeader
                    }
                    ForEach(apps, id: \.self) { app in
                        AppRuleRow(
                            model: model,
                            app: app,
                            overrideBase: overrideBase,
                            overrideFloatBase: overrideFloatBase,
                            offersTitles: offersTitles,
                            composingTitles: $composingTitles,
                            onDelete: { delete(app) },
                            returningRow: $returningRow
                        )
                        Divider()
                    }
                    addRow
                    noSpacesNote
                }
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    /// Banner shown when active profile overrides base app rules (#109).
    @ViewBuilder private var overrideIndicator: some View {
        if model.editedProfileOverridesAppRules {
            Label(
                L(
                    "app_rules.override.overrides",
                    "This profile overrides base app rules."
                ),
                systemImage: "app.badge"
            )
            .font(.callout)
        }
    }

    /// The ONE facet heading, drawn over the list. Below the row
    /// breakpoint the rows stack and carry it themselves, so this
    /// goes away rather than compressing.
    @ViewBuilder private var tableHeader: some View {
        if !width.stacksRows {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // The app column needs no heading: an icon and a
                // name are their own.
                Color.clear
                    .frame(
                        width: SettingsMetrics
                            .appRuleIdentityColumn,
                        height: 1
                    )
                Text(L("app_rules.space", "Opens in"))
                    .frame(
                        width: SettingsMetrics.appRuleSpaceColumn,
                        alignment: .leading
                    )
                // The float column carries NO heading: its values
                // are whole predicates and name themselves, so a
                // heading would be a word the rows do not need.
                Spacer(minLength: 8)
            }
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
            // Drawn, not spoken: each control below names itself,
            // so a heading read aloud is the same words twice.
            .accessibilityHidden(true)
        }
    }

    var offersTitles: Bool {
        AppRuleTitleOffer.isOffered(
            mode: model.settingsMode,
            floatRules: model.config.floatRules
                + (overrideFloatBase ?? [])
        )
    }

    /// Sorted list of unique apps with configured rules (#333,
    /// #109).
    private var apps: [String] {
        var set = Set(model.config.appRules.keys)
        for rule in model.config.floatRules {
            set.insert(FloatFacet.appSegment(of: rule))
        }
        if let base = overrideBase {
            set.formUnion(base.keys)
        }
        if let base = overrideFloatBase {
            for rule in base {
                set.insert(FloatFacet.appSegment(of: rule))
            }
        }
        // The row under composition, which may hold no stored rule
        // for as long as its editor is open.
        if let composing = composingTitles {
            set.insert(composing)
        }
        let names = Dictionary(
            uniqueKeysWithValues: set.map {
                ($0, KeybindingCatalog.displayName(forBundleID: $0))
            }
        )
        return set.sorted { lhs, rhs in
            let order = (names[lhs] ?? lhs)
                .localizedCaseInsensitiveCompare(names[rhs] ?? rhs)
            if order == .orderedSame { return lhs < rhs }
            return order == .orderedAscending
        }
    }

    private var emptyNote: some View {
        Text(
            L(
                "app_rules.empty",
                "Apps with no rule tile normally, in whichever "
                    + "Space you open them."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// With no Spaces declared there is nothing to open in, so the
    /// remedy lives on another destination — a live pointer naming
    /// it, which is what a gate whose cause is off this surface
    /// owes (#815).
    @ViewBuilder private var noSpacesNote: some View {
        if model.config.spaces.isEmpty {
            CrossReferenceRow(
                prose: Self.noSpacesProse,
                linkTitle: SettingsDestination.spaces.title,
                destination: .spaces
            )
        }
    }

    /// Computed per read, never stored: a `static let` resolves
    /// `L()` once and keeps that locale for the process (#1311).
    static var noSpacesProse: String {
        L(
            "app_rules.no_spaces",
            "This profile has no Spaces yet, so there is nothing "
                + "to open an app in. Add one in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    /// Two pickers, because the rule is chosen before the app: a
    /// row that says nothing can no longer be created (#1022), and
    /// picking the app is still the whole gesture (#1172).
    private var addRow: some View {
        HStack(spacing: 8) {
            AppSelector(
                role: .space,
                name: $newSpaceApp,
                exclude: Set(apps),
                onCommit: addWithSpace
            )
            .disabled(model.config.spaces.isEmpty)
            AppSelector(
                role: .float,
                name: $newFloatingApp,
                exclude: Set(apps),
                onCommit: addFloating
            )
            Spacer()
        }
    }

    /// Adds a rule that pins the picked app to the designated
    /// Space. Picking an app is the whole gesture (#1172), so this
    /// runs straight off the pick.
    private func addWithSpace(_ picked: String) {
        // Cleared whatever happens: a refused pick used to stay in
        // the binding, and `AppPickerButton` draws and announces
        // whatever `name` holds — so the button read the refused
        // app's name until an unrelated pick succeeded (code
        // review, 2026-09-22).
        defer { newSpaceApp = "" }
        guard let app = normalized(picked),
            let space = AppRulePin.engagedSpace(model.config)
        else { return }
        model.config.appRules[app] = space
    }

    /// Adds a rule that floats every window of the picked app.
    private func addFloating(_ picked: String) {
        defer { newFloatingApp = "" }
        guard let app = normalized(picked) else { return }
        if !model.config.floatRules.contains(app) {
            model.config.floatRules.append(app)
        }
    }

    /// Lower-cased so a hand-typed mixed-case bundle id
    /// (osascript reports `com.apple.Safari`) keys the same as the
    /// normalized `appBundleID` the engine and dropdown use —
    /// otherwise dedup and the open-title list silently miss
    /// (#262 review).
    private func normalized(_ picked: String) -> String? {
        let app = picked.trimmed.lowercased()
        guard !app.isEmpty, !apps.contains(app) else { return nil }
        return app
    }

    /// Removes app rules and updates focus target (#816, #109, 2026-08-12).
    private func delete(_ app: String) {
        let neighbour = neighbourAfterDeleting(app)
        model.config.appRules[app] = nil
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
        // Or the deleted row is the one the composing slot keeps
        // listed, and the trash appears to do nothing.
        if composingTitles == app { composingTitles = nil }
        if !apps.contains(app) {
            returningRow = neighbour
        }
    }

    private func neighbourAfterDeleting(
        _ app: String
    ) -> String? {
        DeletionFocus.neighbour(after: app, in: apps)
    }
}
