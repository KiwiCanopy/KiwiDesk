import KiwiDeskCore
import SwiftUI

/// The "Applies to" control for the shared look (#1752): App
/// Rules' closed label and popover, with the look's own tick rules —
/// a tick is "this profile follows the shared look", every box
/// stays live, and no ⚠ marks an own look, which is a choice rather
/// than a divergence.
struct LookReachControl: View {
    @ObservedObject var model: SettingsModel
    /// The profile whose page this is.
    let edited: String
    @State private var request: LookReachRequest?

    var body: some View {
        let label = LookReachWords.label(
            follows: model.lookFollows,
            order: model.profileMenuOrder,
            edited: edited
        )
        Button {
            request = LookReachRequest(id: edited)
        } label: {
            AppRuleMenuLabel(text: label)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(SettingsTheme.ink)
        .frame(minWidth: SettingsMetrics.ruleReachColumn, alignment: .leading)
        .help(label)
        .accessibilityLabel(L("app_rules.reach", "Applies to"))
        .accessibilityValue(label)
        .popover(item: $request, arrowEdge: .bottom) { _ in
            LookReachChecklist(model: model, edited: edited)
        }
    }
}

/// The popover's request — built from ONE row (#843).
struct LookReachRequest: Identifiable {
    let id: String
}

/// The words the control says, one home for its drawn and spoken
/// forms. The label reads from the edited profile: the profiles
/// that wear its look.
@MainActor
enum LookReachWords {
    static func label(
        follows: [String: Bool],
        order: [String],
        edited: String
    ) -> String {
        guard follows[edited] == true else {
            return L("looks.reach.own", "Own look")
        }
        let users = order.filter { follows[$0] == true }
        if users.count == order.count {
            return RuleReachWords.allProfiles
        }
        switch users.count {
        case 1:
            return L("app_rules.reach.only", "%1$@ only", users[0])
        case 2:
            return L(
                "app_rules.reach.pair",
                "%1$@, %2$@",
                users[0],
                users[1]
            )
        default:
            return L(
                "app_rules.reach.count",
                "Profiles: %1$d",
                users.count
            )
        }
    }
}
