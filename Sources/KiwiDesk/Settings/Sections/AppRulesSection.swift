import KiwiDeskCore
import SwiftUI

/// Whole App ▸ App Rules settings section (#68 §3.11, #1608).
///
/// Two lists, matching the two stores `GuiConfig` keeps: which
/// Space an app's windows open in, and which of its windows
/// float. The Space is title-blind, so a title pattern belongs
/// to the Float list alone (`docs/design-decisions.md` ▸ App
/// rules).
struct AppRulesSection: View {
    @ObservedObject var model: SettingsModel
    /// Restore keyboard focus after deleting a row (#816), one
    /// per list: an app may sit in both.
    @FocusState var returningSpaceRow: String?
    @FocusState var returningFloatRow: String?
    /// The app whose pattern editor is open. Owned here, not by
    /// the row, because a row composing its first pattern may
    /// hold no stored rule and `floatApps` is derived from the
    /// store — without this the list drops the row mid-gesture
    /// (#1022). It names at most one row and holds no value.
    @State var composingTitles: String?
    @State var newSpaceApp = ""
    @State var newFloatingApp = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                spaceList
                floatList
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
        // The composing row belongs to the draft it was opened in.
        // Every reload — an edit-target switch, a Revert — replaces
        // the draft's baseline, and a slot carried across one lists
        // an empty row, editor open, in a draft that never had it.
        .onChange(of: model.cleanConfig) { composingTitles = nil }
    }

    /// The area's census gates, from one construction site for
    /// both lists and every row.
    var gates: AppRulesGates {
        AppRulesGates(config: model.config)
    }

    /// Whether the rows draw the "Applies to" column (#1393).
    var showsReach: Bool { model.offersReachColumn }

    var offersTitles: Bool {
        AppRuleTitleOffer.isOffered(
            mode: model.settingsMode,
            gates: gates
        )
    }

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
