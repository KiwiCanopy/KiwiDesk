import KiwiDeskCore
import SwiftUI

/// The "Applies to" column of an App Rules row (#1393): the
/// closed label, the ⚠ for a profile that differs, and the
/// checklist popover.
struct RuleReachControl: View {
    @ObservedObject var model: SettingsModel
    let family: RuleFamily
    let app: String
    let reading: RuleReachReading
    /// The row's value in words, for the popover's top line.
    let value: String
    @State private var request: RuleReachRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                request = RuleReachRequest(id: app)
            } label: {
                AppRuleMenuLabel(text: RuleReachWords.label(reading))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(
                reading.shared ? SettingsTheme.ink2 : SettingsTheme.ink
            )
            .fixedSize()
            .accessibilityLabel(L("app_rules.reach", "Applies to"))
            .accessibilityValue(RuleReachWords.spoken(reading))
            .popover(item: $request, arrowEdge: .bottom) { _ in
                RuleReachChecklist(
                    model: model,
                    family: family,
                    app: app,
                    value: value
                )
            }
            if let warning = RuleReachWords.differing(reading) {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.warningInk)
                    .padding(.leading, 4)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// The popover's request — built from ONE row (#843).
struct RuleReachRequest: Identifiable {
    let id: String
}

/// The words the column and its popover say (#1393), one home so
/// the drawn and spoken forms cannot drift. A count goes last
/// (localization.md).
@MainActor
enum RuleReachWords {
    static func label(_ reading: RuleReachReading) -> String {
        if reading.shared {
            return L("app_rules.reach.all", "All profiles")
        }
        let users = reading.profiles.filter(reading.users.contains)
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
            return L("app_rules.reach.count", "Profiles: %1$d", users.count)
        }
    }

    static func differing(_ reading: RuleReachReading) -> String? {
        let names = reading.differing
        switch names.count {
        case 0: return nil
        case 1:
            return L(
                "app_rules.reach.differs.one",
                "⚠ Different in %1$@",
                names[0]
            )
        case 2:
            return L(
                "app_rules.reach.differs.two",
                "⚠ Different in %1$@, %2$@",
                names[0],
                names[1]
            )
        default:
            return L(
                "app_rules.reach.differs.many",
                "⚠ Different in profiles: %1$d",
                names.count
            )
        }
    }

    /// The control's announced value: the label, and the profiles
    /// that differ, which the drawn ⚠ says below it.
    static func spoken(_ reading: RuleReachReading) -> String {
        let names = reading.differing
        guard !names.isEmpty else { return label(reading) }
        return L(
            "app_rules.reach.spoken_differs",
            "%1$@; different in %2$@",
            label(reading),
            names.joined(separator: ", ")
        )
    }
}
