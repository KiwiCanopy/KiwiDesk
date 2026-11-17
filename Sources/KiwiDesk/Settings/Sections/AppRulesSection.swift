import KiwiDeskCore
import SwiftUI

/// Whole App ▸ App Rules settings section (#68 §3.11, #1608).
///
/// Two lists over their own stores: which Space an app's windows
/// open in — one row per app and title pattern (#3341) — and which
/// of its windows float. A pattern scopes the row it sits in
/// (`docs/design-decisions.md` ▸ App rules).
struct AppRulesSection: View {
    @ObservedObject var model: SettingsModel
    /// Restore keyboard focus after deleting a row (#816), one
    /// per list: an app may sit in both.
    @FocusState var returningSpaceRow: String?
    @FocusState var returningFloatRow: String?
    @FocusState var returningTileRow: String?
    /// The app whose pattern editor is open. Owned here, not by
    /// the row, because a row composing its first pattern may
    /// hold no stored rule and `floatApps` is derived from the
    /// store — without this the list drops the row mid-gesture
    /// (#1022). It names at most one row and holds no value.
    @State var composingTitles: String?
    /// The Space card's one open title popover (#3373), owned here
    /// so the card has one at a time and a reload closes it.
    @State var composingSpace: SpaceComposer?
    @State var newSpaceApp = ""
    @State var newFloatingApp = ""
    @State var newTileApp = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                spaceList
                floatList
                automaticList
            }
            .padding(.horizontal, SettingsMetrics.paneInset)
            .settingsPageBottom()
        }
        // The composing row belongs to the draft it was opened in.
        // Every reload — an edit-target switch, a Revert — replaces
        // the draft's baseline, and a slot carried across one lists
        // an empty row, editor open, in a draft that never had it.
        .onChange(of: model.cleanConfig) {
            composingTitles = nil
            composingSpace = nil
        }
    }

    /// The list card holding `app`'s rule — the Space list first —
    /// where a bar menu's App Rules… lands (#1518): the Automatic
    /// floating card for a Tile rule, or for an app a guess floats
    /// (#2173); nil for any other app, which lands on the page and
    /// creates none.
    @MainActor
    static func card(
        holding app: String,
        in model: SettingsModel
    ) -> SettingsControl? {
        let app = app.lowercased()
        if SpaceRuleRows.apps(model.config).contains(app) {
            return SettingsCatalog.appRules.spaceList
        }
        let floats = model.config.floatRules.map(FloatFacet.appSegment(of:))
        if floats.contains(AppTitleRule.appKey(app)) {
            return SettingsCatalog.appRules.floatList
        }
        let tiles = model.config.tileRules.map(FloatGuess.normalizedRule)
        if tiles.contains(app) || model.core.floatsOnGuess(app: app) {
            return SettingsCatalog.appRules.automaticList
        }
        return nil
    }

    /// The area's census gates, from one construction site for
    /// both lists and every row.
    var gates: AppRulesGates {
        AppRulesGates(config: model.config)
    }

    /// Whether the rows draw the "Applies to" column (#1393).
    var showsReach: Bool { model.offersReachColumn }

    /// With both lists empty the card says what an unruled app
    /// does — once, for the whole area.
    var hasNoRules: Bool { spaceApps.isEmpty && floatApps.isEmpty }

    /// Sorted by display name, then bundle id for a stable tie.
    func sortedByName(_ set: Set<String>) -> [String] {
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

    /// Lower-cased so a hand-typed mixed-case bundle id
    /// (osascript reports `com.apple.Safari`) keys the same as the
    /// normalized `appBundleID` the engine and dropdown use
    /// (#262 review). Refused where the list already holds it.
    func normalized(_ picked: String, in list: [String]) -> String? {
        let app = picked.trimmed.lowercased()
        guard !app.isEmpty, !list.contains(app) else { return nil }
        return app
    }
}
