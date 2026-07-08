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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection(
                    L("app_rules.section.title", "Rules per app")
                ) {
                    Text(rulesCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(apps, id: \.self) { app in
                        AppRuleRow(
                            model: model,
                            app: app,
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

    private var rulesCaption: String {
        L(
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
    /// installed still render (name as typed).
    private var apps: [String] {
        var set = Set(model.config.appRules.keys)
        for rule in model.config.floatRules {
            set.insert(FloatFacet.appSegment(of: rule))
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
            .disabled(newApp.trimmed.isEmpty)
            Spacer()
        }
    }

    private func delete(_ app: String) {
        model.config.appRules[app] = nil
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
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
