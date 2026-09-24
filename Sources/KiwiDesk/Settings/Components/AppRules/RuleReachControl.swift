import KiwiDeskCore
import SwiftUI

/// The "Applies to" column of an App Rules row (#1393): the
/// closed label with a ⚠ beside it where a profile differs — the
/// names ride its tooltip and the spoken value, the checklist
/// holds the detail — and the checklist popover.
struct RuleReachControl: View {
    @ObservedObject var model: SettingsModel
    let family: RuleFamily
    let app: String
    /// What the row is about, in words (`RuleReachChecklist`).
    let subject: String
    let reading: RuleReachReading
    /// The row's value in words, for the popover's top line.
    let value: String
    @State private var request: RuleReachRequest?

    var body: some View {
        let warning = RuleReachWords.differing(reading)
        Button {
            request = RuleReachRequest(id: app)
        } label: {
            HStack(spacing: 4) {
                AppRuleMenuLabel(text: RuleReachWords.label(reading))
                if warning != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.warningInk)
                }
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(
            reading.shared ? SettingsTheme.ink2 : SettingsTheme.ink
        )
        .frame(width: SettingsMetrics.ruleReachColumn, alignment: .leading)
        .help(warning ?? "")
        .accessibilityLabel(L("app_rules.reach", "Applies to"))
        .accessibilityValue(RuleReachWords.spoken(reading))
        .popover(item: $request, arrowEdge: .bottom) { _ in
            RuleReachChecklist(
                model: model,
                family: family,
                app: app,
                subject: subject,
                value: value
            )
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
    /// The checkbox's label, which every sentence naming it
    /// interpolates (#818).
    static var allProfiles: String {
        L("app_rules.reach.all", "All profiles")
    }

    static func label(_ reading: RuleReachReading) -> String {
        if reading.shared { return allProfiles }
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

    /// The trash's "this profile" choice.
    static func removeHere(_ reading: RuleReachReading) -> String {
        L("app_rules.remove.here", "Remove from %1$@", reading.editing)
    }

    /// The trash's other choice: every profile holding this value —
    /// named while there are two, counted past that, and "every
    /// profile" only when that is all of them.
    static func removeEverywhere(_ reading: RuleReachReading) -> String {
        let users = reading.profiles.filter(reading.users.contains)
        if users.count >= reading.profiles.count {
            return L(
                "app_rules.remove.everywhere",
                "Remove from every profile"
            )
        }
        if users.count == 2 {
            return L(
                "app_rules.remove.pair",
                "Remove from %1$@ and %2$@",
                users[0],
                users[1]
            )
        }
        return L(
            "app_rules.remove.count",
            "Remove from every profile using it (%1$d)",
            users.count
        )
    }

    /// The ⚠ a shared row owes: a profile that differs does not
    /// follow a change made under All profiles. A list says who it
    /// reaches already, so it owes none.
    static func differing(_ reading: RuleReachReading) -> String? {
        guard reading.shared else { return nil }
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

    /// The control's announced value: the label, and the ⚠ the
    /// row draws below it, whose names each locale joins itself.
    static func spoken(_ reading: RuleReachReading) -> String {
        guard let differs = differing(reading) else { return label(reading) }
        return L(
            "app_rules.reach.spoken_differs",
            "%1$@; %2$@",
            label(reading),
            differs
        )
    }
}
