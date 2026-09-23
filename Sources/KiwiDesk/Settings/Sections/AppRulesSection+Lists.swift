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
                    overrideBase: overrideBase,
                    gates: gates,
                    onDelete: { deleteSpace(app) },
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

    /// Apps this list draws: every pin, and while a stored profile
    /// is edited every BASE pin too — a profile's stored nil is the
    /// tombstone that un-pins it, and the row stays to be restored.
    var spaceApps: [String] {
        var set = Set(model.config.appRules.keys)
        if let base = overrideBase { set.formUnion(base.keys) }
        return sortedByName(set)
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

    private func deleteSpace(_ app: String) {
        let neighbour = DeletionFocus.neighbour(after: app, in: spaceApps)
        model.config.appRules[app] = nil
        if !spaceApps.contains(app) { returningSpaceRow = neighbour }
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
                    overrideFloatBase: overrideFloatBase,
                    offersTitles: offersTitles,
                    composingTitles: $composingTitles,
                    onDelete: { deleteFloat(app) },
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

    /// Apps this list draws: every float rule, the base's while a
    /// stored profile is edited, and the row under composition,
    /// which may hold no stored rule while its editor is open.
    var floatApps: [String] {
        var rules = model.config.floatRules
        rules += overrideFloatBase ?? []
        var set = Set(rules.map(FloatFacet.appSegment(of:)))
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

    private func deleteFloat(_ app: String) {
        let neighbour = DeletionFocus.neighbour(after: app, in: floatApps)
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
        // Or the deleted row is the one the composing slot keeps
        // listed, and the trash appears to do nothing.
        if composingTitles == app { composingTitles = nil }
        if !floatApps.contains(app) { returningFloatRow = neighbour }
    }
}
