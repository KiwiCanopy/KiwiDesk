import KiwiDeskCore
import SwiftUI

/// Whole App ▸ App Rules settings section (#68 §3.11).
struct AppRulesSection: View {
    @ObservedObject var model: SettingsModel
    @State private var draftApps: [String] = []
    /// Restores keyboard focus after deleting a rule row (#816).
    @FocusState private var returningRow: String?
    @State private var newApp = ""

    /// Base rules when editing stored profile (#109); nil during live editing.
    private var overrideBase: [String: SpaceID]? {
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
                    caption: rulesCaption
                ) {
                    overrideIndicator
                    if apps.isEmpty {
                        emptyNote
                    }
                    ForEach(apps, id: \.self) { app in
                        AppRuleRow(
                            model: model,
                            app: app,
                            overrideBase: overrideBase,
                            overrideFloatBase: overrideFloatBase,
                            isDraft: draftApps.contains(app),
                            onDelete: { delete(app) },
                            returningRow: $returningRow
                        )
                        Divider()
                    }
                    addRow
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

    private var rulesCaption: String {
        if overrideBase != nil {
            return L(
                "app_rules.override.caption",
                "Space and float rules made here apply to this "
                    + "profile only. Dimmed facets are inherited "
                    + "from the app-wide base rules and stay "
                    + "in sync with them; changing a facet "
                    + "overrides it for this profile, and "
                    + "deleting a row removes inherited rules "
                    + "here. To edit the base rules themselves, "
                    + "switch back to the currently "
                    + "loaded profile in the header's picker."
            )
        }
        return L(
            "app_rules.section.caption",
            "What an app should do when it opens."
        )
    }

    /// Sorted list of unique apps with configured rules or drafts (#333,
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
        set.formUnion(draftApps)
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

    private var addRow: some View {
        HStack {
            AppSelector(
                name: $newApp,
                exclude: Set(apps),
                onCommit: add
            )
            Spacer()
        }
    }

    /// Adds the rule the selector committed. Picking an app is
    /// the whole gesture (#1172), so this runs straight off the
    /// pick — the picked-but-not-added state it replaces was
    /// also the one state that drew no icon.
    private func add(_ picked: String) {
        // Lower-cased so a hand-typed mixed-case bundle
        // id (osascript reports `com.apple.Safari`) keys
        // the same as the normalized `appBundleID` the
        // engine and dropdown use — otherwise dedup and
        // the open-title list silently miss (#262 review).
        let app = picked.trimmed.lowercased()
        guard !app.isEmpty else { return }
        if !apps.contains(app) {
            draftApps.append(app)
        }
        newApp = ""
    }

    /// Removes app rules and updates focus target (#816, #109, 2026-08-12).
    private func delete(_ app: String) {
        let neighbour = neighbourAfterDeleting(app)
        model.config.appRules[app] = nil
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
        draftApps.removeAll { $0 == app }
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

/// Float facet parsing and filtering helper matching `FloatRules`.
enum FloatFacet: Equatable {
    case never
    case all
    case titled

    /// Extracts app segment from float rule string (`FloatRules`).
    static func appSegment(of rule: String) -> String {
        let parts = rule.split(separator: ":", maxSplits: 1)
        return parts.count == 2 ? String(parts[0]) : rule
    }

    static func current(
        _ rules: [String],
        app: String
    ) -> FloatFacet {
        var sawTitled = false
        for rule in rules where appSegment(of: rule) == app {
            if rule == app { return .all }
            sawTitled = true
        }
        return sawTitled ? .titled : .never
    }

    static func patterns(
        _ rules: [String],
        app: String
    ) -> [String] {
        rules.compactMap { rule in
            let parts = rule.split(
                separator: ":",
                maxSplits: 1
            )
            guard parts.count == 2,
                String(parts[0]) == app
            else { return nil }
            return String(parts[1])
        }
    }

    static func rules(_ rules: [String], app: String) -> [String] {
        rules.filter { appSegment(of: $0) == app }
    }
}
