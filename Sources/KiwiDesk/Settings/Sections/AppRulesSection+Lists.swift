import KiwiDeskCore
import SwiftUI

/// The two lists App Rules draws (#1608): each a card of its own,
/// with its rows, its picker and its deletion.
extension AppRulesSection {
    // MARK: - Open in a Space

    var spaceList: some View {
        SettingsSection(
            SettingsCatalog.appRules.spaceList,
            caption: Self.spaceCaption,
            help: Self.spaceHelp
        ) {
            if hasNoRules { emptyNote }
            ForEach(spaceGroups, id: \.self) { group in
                ForEach(group) { row in
                    AppRuleSpaceRow(
                        model: model,
                        row: row,
                        first: row == group.first,
                        siblings: titledFragments(of: row.app),
                        gates: gates,
                        showsReach: showsReach,
                        composing: $composingSpace,
                        onDelete: { deleteSpace(row, $0) },
                        returningRow: $returningSpaceRow
                    )
                }
                Divider()
            }
            AppSelector(
                role: .space,
                name: $newSpaceApp,
                exclude: bareSpaceApps,
                onCommit: addWithSpace,
                openAppsOf: model.core
            )
            .disabled(!gates.hasSpaces)
            noSpacesNote
        }
    }

    /// Apps this list draws: every rule the edited profile
    /// resolves (#1393), bare or titled (#3341).
    var spaceApps: [String] {
        sortedByName(SpaceRuleRows.apps(model.config))
    }

    /// Each app's rows in the engine's order.
    var spaceGroups: [[SpaceRuleRow]] {
        SpaceRuleRows.groups(model.config, apps: spaceApps)
    }

    /// The picker leaves out only apps with a bare Space rule, so an
    /// app with titled rows alone can have its bare row back (#3341).
    var bareSpaceApps: Set<String> {
        Set(model.config.appRules.keys)
    }

    /// `app`'s titled fragments.
    func titledFragments(of app: String) -> [String] {
        TitledSpaceRules(model.config.titledAppRules).order(of: app)
            .map(\.fragment)
    }

    /// Pins the picked app to the Space a new pin takes. Picking
    /// the app is the whole gesture (#1172).
    private func addWithSpace(_ picked: String) {
        // Cleared whatever happens: `AppPickerButton` draws what
        // `name` holds, so a refused pick would stay drawn.
        defer { newSpaceApp = "" }
        guard let app = normalized(picked, in: Array(bareSpaceApps)),
            let space = AppRulePin.engagedSpace(model.config)
        else { return }
        model.config.appRules[app] = space
    }

    private func deleteSpace(_ row: SpaceRuleRow, _ removal: RuleRemoval) {
        let keys = spaceGroups.flatMap { $0 }.map(\.key)
        let neighbour = DeletionFocus.neighbour(after: row.key, in: keys)
        if row.fragment == nil {
            model.recordRemoval(.space, row.app, removal)
        } else {
            model.recordRemoval(.titledSpace, row.key, removal)
        }
        SpaceRuleEdit.drop(row, from: &model.config)
        returningSpaceRow = neighbour
    }

    /// With no Spaces declared there is nothing to open in, so the
    /// remedy lives on another destination — a live pointer naming
    /// it, which is what a gate whose cause is off this surface
    /// owes (#815).
    @ViewBuilder private var noSpacesNote: some View {
        if !gates.hasSpaces {
            CrossReferenceRow(
                prose: Self.noSpacesProse,
                linkTitle: SettingsDestination.spaces.title,
                destination: .spaces
            )
        }
    }

    private var emptyNote: some View {
        Text(Self.emptyProse)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Float

    var floatList: some View {
        SettingsSection(
            SettingsCatalog.appRules.floatList,
            caption: Self.floatCaption,
            help: floatHelp
        ) {
            ForEach(floatApps, id: \.self) { app in
                AppRuleFloatRow(
                    model: model,
                    app: app,
                    showsReach: showsReach,
                    composingTitles: $composingTitles,
                    onDelete: { deleteFloat(app, $0) },
                    returningRow: $returningFloatRow
                )
                Divider()
            }
            AppSelector(
                role: .float,
                name: $newFloatingApp,
                exclude: Set(floatApps),
                onCommit: addFloating,
                openAppsOf: model.core
            )
        }
    }

    /// Apps this list draws: every float rule the edited profile
    /// resolves, and the row under composition, which may hold no
    /// stored rule while its editor is open.
    var floatApps: [String] {
        var set = Set(model.config.floatRules.map(FloatFacet.appSegment(of:)))
        if let composing = composingTitles { set.insert(composing) }
        return sortedByName(set)
    }

    /// Floats every window of the picked app.
    private func addFloating(_ picked: String) {
        defer { newFloatingApp = "" }
        guard let app = normalized(picked, in: floatApps) else {
            return
        }
        model.config.floatRules.append(app)
    }

    private func deleteFloat(_ app: String, _ removal: RuleRemoval) {
        let neighbour = DeletionFocus.neighbour(after: app, in: floatApps)
        model.recordRemoval(.float, app, removal)
        model.config.floatRules = FloatFacet.removingRules(
            of: app,
            from: model.config.floatRules
        )
        // Or the deleted row is the one the composing slot keeps
        // listed, and the trash appears to do nothing.
        if composingTitles == app { composingTitles = nil }
        returningFloatRow = floatApps.contains(app) ? app : neighbour
    }
}
