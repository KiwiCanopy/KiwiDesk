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
            ForEach(spaceApps, id: \.self) { app in
                AppRuleSpaceRow(
                    model: model,
                    app: app,
                    gates: gates,
                    showsReach: showsReach,
                    onDelete: { deleteSpace(app, $0) },
                    returningRow: $returningSpaceRow
                )
                Divider()
            }
            AppSelector(
                role: .space,
                name: $newSpaceApp,
                exclude: Set(spaceApps),
                onCommit: addWithSpace
            )
            .disabled(!gates.hasSpaces)
            noSpacesNote
        }
    }

    /// Apps this list draws: every rule the edited profile
    /// resolves (#1393).
    var spaceApps: [String] {
        sortedByName(Set(model.config.appRules.keys))
    }

    /// Pins the picked app to the Space a new pin takes. Picking
    /// the app is the whole gesture (#1172).
    private func addWithSpace(_ picked: String) {
        // Cleared whatever happens: `AppPickerButton` draws what
        // `name` holds, so a refused pick would stay drawn.
        defer { newSpaceApp = "" }
        guard let app = normalized(picked, in: spaceApps),
            let space = AppRulePin.engagedSpace(model.config)
        else { return }
        model.config.appRules[app] = space
    }

    private func deleteSpace(_ app: String, _ removal: RuleRemoval) {
        let neighbour = DeletionFocus.neighbour(after: app, in: spaceApps)
        model.recordRemoval(.space, app, removal)
        model.config.appRules[app] = nil
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
                    offersTitles: offersTitles,
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
                onCommit: addFloating
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
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
        // Or the deleted row is the one the composing slot keeps
        // listed, and the trash appears to do nothing.
        if composingTitles == app { composingTitles = nil }
        returningFloatRow = floatApps.contains(app) ? app : neighbour
    }
}
