import KiwiDeskCore
import SwiftUI

/// App Rules ▸ Automatic floating (#2173): the switch on top, and
/// the Tile list it gates — its exceptions — below it.
extension AppRulesSection {
    var automaticList: some View {
        SettingsSection(
            SettingsCatalog.appRules.automaticList,
            caption: AutoFloatWords.caption
        ) {
            AutoFloatSwitchRow(model: model, showsReach: showsReach)
            if !automaticOn, !tileApps.isEmpty {
                Text(AutoFloatWords.offNote)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
            }
            Divider()
            HStack(spacing: 6) {
                Text(AutoFloatWords.tileTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                HelpButton(
                    explanation: AutoFloatWords.tileHelp,
                    subject: AutoFloatWords.tileTitle
                )
            }
            .padding(.top, 4)
            ForEach(tileApps, id: \.self) { app in
                AppRuleTileRow(
                    model: model,
                    app: app,
                    showsReach: showsReach,
                    dimmed: !automaticOn,
                    onDelete: { deleteTile(app, $0) },
                    returningRow: $returningTileRow
                )
                Divider()
            }
            AppSelector(
                role: .tile,
                name: $newTileApp,
                exclude: Set(tileApps),
                guessed: { model.core.guessedFloatApps() },
                onCommit: addTile
            )
            .modifier(
                GreyOut(active: !automaticOn, help: AutoFloatWords.offNote)
            )
        }
    }

    private var automaticOn: Bool { gates.automaticFloats }

    /// Apps this list draws: every Tile rule the edited profile
    /// resolves.
    var tileApps: [String] {
        sortedByName(
            Set(model.config.tileRules.map(FloatGuess.normalizedRule))
        )
    }

    private func addTile(_ picked: String) {
        defer { newTileApp = "" }
        guard let app = normalized(picked, in: tileApps) else { return }
        model.config.tileRules.append(app)
    }

    private func deleteTile(_ app: String, _ removal: RuleRemoval) {
        let neighbour = DeletionFocus.neighbour(after: app, in: tileApps)
        model.recordRemoval(.tile, app, removal)
        model.config.tileRules.removeAll {
            FloatGuess.normalizedRule($0) == app
        }
        returningTileRow = neighbour
    }
}

/// The "Float windows automatically" switch and its "Applies to".
struct AutoFloatSwitchRow: View {
    @ObservedObject var model: SettingsModel
    let showsReach: Bool

    var body: some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: SettingsMetrics.appRuleColumnSpacing
        ) {
            Toggle(
                AutoFloatWords.title,
                isOn: $model.config.floatAutomatically
            )
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityValue(
                AutoFloatWords.value(model.config.floatAutomatically)
            )
            HelpButton(
                explanation: AutoFloatWords.help,
                subject: AutoFloatWords.title
            )
            if showsReach, let reading = model.autoFloatReach() {
                RuleReachControl(
                    model: model,
                    family: .autoFloat,
                    app: RuleReachTable<Bool>.floatAutomaticallyKey,
                    subject: AutoFloatWords.title,
                    reading: reading,
                    value: AutoFloatWords.value(
                        model.config.floatAutomatically
                    )
                )
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

/// One row of the Tile list: an app, which profiles it reaches,
/// and the trash. Its identity dims while the switch is off, the
/// trash and the reach staying live for other profiles.
struct AppRuleTileRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    let showsReach: Bool
    let dimmed: Bool
    let onDelete: (RuleRemoval) -> Void
    @FocusState.Binding var returningRow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(
                alignment: .firstTextBaseline,
                spacing: SettingsMetrics.appRuleColumnSpacing
            ) {
                AppRuleIdentity(app: app)
                    .modifier(
                        GreyOut(active: dimmed, help: AutoFloatWords.offNote)
                    )
                if showsReach, let reading = model.tileReach(app) {
                    RuleReachControl(
                        model: model,
                        family: .tile,
                        app: app,
                        subject: KeybindingCatalog.displayName(
                            forBundleID: app
                        ),
                        reading: reading,
                        value: AutoFloatWords.tiles
                    )
                }
                Spacer(minLength: SettingsMetrics.appRuleColumnSpacing)
                AppRuleDeleteButton(
                    help: AutoFloatWords.removeHelp,
                    sharedFrom: sharedFrom,
                    onDelete: onDelete
                )
                // The row's focus destination (#816).
                .focused($returningRow, equals: app)
            }
            if Self.floatsEveryWindow(app: app, config: model.config) {
                Text(AutoFloatWords.inert)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.warningInk)
                    .padding(.leading, SettingsMetrics.appRuleIdentityInset)
            }
        }
        .font(.callout)
    }

    /// A Float rule for every window of the app leaves nothing for
    /// this rule to tile — the Float list's own facet reading.
    static func floatsEveryWindow(app: String, config: GuiConfig) -> Bool {
        FloatFacet.current(config.floatRules, app: app) == .all
    }

    private var sharedFrom: RuleReachReading? {
        guard showsReach, let reading = model.tileReach(app),
            reading.users.count > 1
        else { return nil }
        return reading
    }
}

/// The card's words — one home for the rows, the diff readout and
/// the checklist. Computed per read (#1311).
@MainActor
enum AutoFloatWords {
    static var caption: String {
        L(
            "app_rules.auto_list.caption",
            "KiwiDesk floats windows that can’t be resized, like many "
                + "apps’ Settings windows, and apps without a Dock "
                + "icon, like menu-bar apps."
        )
    }

    static var title: String {
        L("app_rules.auto_float", "Float windows automatically")
    }

    static var help: String {
        L(
            "app_rules.auto_float.help",
            "Usually that guess is right. Edit the list below where "
                + "it is wrong for an app.\n\nTurn it off and only your "
                + "Float rules float a window. Dialogs, sheets and "
                + "panels float either way."
        )
    }

    static func value(_ on: Bool) -> String {
        on
            ? L("app_rules.auto_float.on", "On")
            : L("app_rules.auto_float.off", "Off")
    }

    static var offNote: String {
        L(
            "app_rules.auto_float.off_note",
            "Off, so only Float rules float a window here. Tile rules "
                + "have nothing to change."
        )
    }

    static var tileTitle: String { L("app_rules.tile", "Tile instead") }

    static var tileHelp: String {
        L(
            "app_rules.tile.help",
            "A Tile rule tiles an app’s windows that would otherwise "
                + "float automatically. Dialogs, sheets and panels still "
                + "float, and a Float rule for the same app still floats "
                + "the windows it matches."
        )
    }

    static var tiles: String { L("app_rules.tile.tiles", "Tiles") }

    static var removeHelp: String {
        L("app_rules.tile.remove.help", "Remove this Tile rule")
    }

    static var inert: String {
        L(
            "app_rules.tile.inert",
            "⚠ Its Float rule already floats every window, so this "
                + "Tile rule has no effect."
        )
    }
}
