import KiwiDeskCore
import SwiftUI

/// Whole App ▸ App Rules (#68 §3.11): one list, one row per
/// app, with the app's rules as two structured facets — Space
/// (pin to a space) and Float (never tile). Replaces the two
/// mismatched lists whose `App:Title` colon syntax leaked the
/// serialization format into the UI; storage is untouched
/// (`app_rules` dict + `float_rules` strings), the GUI now
/// assembles the syntax.
struct AppRulesSection: View {
    @ObservedObject var model: SettingsModel
    /// Apps added this session that have no stored rule yet
    /// (both facets still at their defaults) — they live only
    /// in the GUI until a facet is set.
    @State private var draftApps: [String] = []
    @State private var newApp = ""

    /// The base rules while editing a stored profile — the
    /// override-mode switch (#109); nil during live editing.
    private var overrideBase: [String: SpaceID]? {
        model.profileEditingBaseAppRules
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection(
                    L("app_rules.section.title", "Rules per app")
                ) {
                    overrideIndicator
                    Text(rulesCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(apps, id: \.self) { app in
                        AppRuleRow(
                            model: model,
                            app: app,
                            overrideBase: overrideBase,
                            onDelete: { delete(app) }
                        )
                        Divider()
                    }
                    addRow
                }
            }
            .padding(16)
        }
    }

    /// Shown while editing a stored profile whose space rules
    /// diverge from the base — the Shortcuts tab's twin (#109).
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
                "Space assignments made here apply to this "
                    + "profile only. Dimmed rows are inherited "
                    + "from the base rules and stay in sync "
                    + "with them; picking another space "
                    + "overrides the rule for this profile, "
                    + "and deleting a row un-pins the app here "
                    + "even when the base pins it. Float rules "
                    + "are app-wide — edit them while editing "
                    + "the live configuration."
            )
        }
        return L(
            "app_rules.section.caption",
            "Pin an app's windows to a space, "
                + "keep them floating, or both. "
                + "Deleting a row removes all of "
                + "the app's rules."
        )
    }

    /// One row per distinct app, however its rules are stored:
    /// assignment key, float-rule app segment, or a session
    /// draft. Hand-written float rules for apps that aren't
    /// installed still render (name as typed). In override
    /// mode the BASE's pinned apps are included too, so a
    /// tombstoned (un-pinned) app keeps its row — visible as
    /// "Automatic" overriding the base pin (#109).
    private var apps: [String] {
        var set = Set(model.config.appRules.keys)
        for rule in model.config.floatRules {
            set.insert(FloatFacet.appSegment(of: rule))
        }
        if let base = overrideBase {
            set.formUnion(base.keys)
        }
        set.formUnion(draftApps)
        return set.sorted()
    }

    private var addRow: some View {
        HStack {
            AppSelector(name: $newApp)
            Button {
                let app = newApp.trimmed
                guard !app.isEmpty else { return }
                if !apps.contains(app) {
                    draftApps.append(app)
                }
                newApp = ""
            } label: {
                Label(
                    L("app_rules.add_rule", "Add app rule"),
                    systemImage: "plus"
                )
            }
            .buttonStyle(.bordered)
            .disabled(newApp.trimmed.isEmpty)
            Spacer()
        }
    }

    private func delete(_ app: String) {
        model.config.appRules[app] = nil
        // Float rules are app-wide (#109): a stored-profile
        // edit must never touch them — the save path only
        // writes the profile JSON, so the edit would either
        // vanish silently or, worse, read as a profile change.
        if overrideBase == nil {
            model.config.floatRules.removeAll {
                FloatFacet.appSegment(of: $0) == app
            }
        }
        draftApps.removeAll { $0 == app }
    }
}

/// The float-facet bridge over `float_rules` strings: `"App"`
/// floats every window, `"App:Title"` floats windows whose
/// title contains the fragment (first colon splits, matching
/// `FloatRules`). The colon is assembled here and never shown.
enum FloatFacet: Equatable {
    case never
    case all
    case titled

    /// Mirrors `FloatRules`' parse exactly: only a rule that
    /// splits into two non-empty-side parts has a title; a
    /// degenerate `"App:"` / `":Title"` is a literal app name
    /// to the engine and must group the same way here.
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
}
