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
        .frame(minWidth: SettingsMetrics.ruleReachColumn, alignment: .leading)
        .help(RuleReachWords.spoken(reading))
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

    /// The words beside a profile's box: "this profile" for the
    /// edited one and "loaded" for the loaded one — both, when the
    /// edited profile is the loaded one (#2022).
    static func mark(_ profile: String, _ reading: RuleReachReading)
        -> String?
    {
        let this = profile == reading.editing
        let loaded = profile == reading.loaded
        if this && loaded {
            return L(
                "app_rules.reach.this_profile_loaded",
                "this profile, loaded"
            )
        }
        if this {
            return L("app_rules.reach.this_profile", "this profile")
        }
        return loaded ? L("app_rules.reach.loaded", "loaded") : nil
    }

    /// The caption under All profiles — or, where the box greys
    /// because the row's layer is not shared, why (#2022): a dim is
    /// not a sentence.
    static func allCaption(_ reading: RuleReachReading) -> String {
        guard reading.shared || reading.layerShared else {
            return L(
                "shortcuts.layer_reach.row_not_shared",
                "Only some profiles have this layer. To share the "
                    + "row, share the layer first."
            )
        }
        return L(
            "app_rules.reach.all_caption",
            "Includes profiles you create later."
        )
    }

    /// The trash's "this profile" choice.
    static func removeHere(_ reading: RuleReachReading) -> String {
        L("app_rules.remove.here", "Remove from %1$@", reading.editing)
    }

    /// The trash's other choice: every profile holding this value —
    /// named while there are two, counted past that, and "every
    /// profile" only when that is all of them.
    static func removeEverywhere(_ reading: RuleReachReading) -> String {
        switch ladder(reading) {
        case .every:
            return L(
                "app_rules.remove.everywhere",
                "Remove from every profile"
            )
        case .pair(let first, let second):
            return L(
                "app_rules.remove.pair",
                "Remove from %1$@ and %2$@",
                first,
                second
            )
        case .count(let count):
            return L(
                "app_rules.remove.count",
                "Remove from every profile using it (%1$d)",
                count
            )
        }
    }

    /// Who a scope reaching every holder reaches, in the one shape
    /// each such wording takes (#2022): every profile, only when
    /// that is all of them; two by name, in menu order; else a
    /// count.
    enum Ladder: Equatable {
        case every
        case pair(String, String)
        case count(Int)
    }

    static func ladder(_ reading: RuleReachReading) -> Ladder {
        let users = reading.profiles.filter(reading.users.contains)
        if users.count >= reading.profiles.count { return .every }
        if users.count == 2 { return .pair(users[0], users[1]) }
        return .count(users.count)
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

    /// The control's announced value and its tooltip: the label, and
    /// what its ⚠ stands for, whose names each locale joins itself.
    static func spoken(_ reading: RuleReachReading) -> String {
        guard let differs = differing(reading) else { return label(reading) }
        return L(
            "app_rules.reach.spoken_differs",
            "%1$@; %2$@",
            label(reading),
            differs
        )
    }

    /// The popover's closing notes: what a tick does from here.
    static func notes(_ reading: RuleReachReading) -> [String] {
        guard reading.shared else { return note(reading).map { [$0] } ?? [] }
        var result = [
            L(
                "app_rules.reach.some_profiles_note",
                "To give only some profiles a new value, untick %1$@ first.",
                RuleReachWords.allProfiles
            )
        ]
        // Once, however many profiles keep their own rule.
        if reading.profiles.contains(where: { reading.own[$0] != nil }) {
            result.append(
                L(
                    "app_rules.reach.replace_own_note",
                    "Ticking a profile with its own rule replaces it "
                        + "with the shared one."
                )
            )
        }
        return result
    }

    private static func note(_ reading: RuleReachReading) -> String? {
        // With a shared rule beside the list, a new profile gets that.
        guard !reading.hasShared,
            reading.profiles.allSatisfy(reading.users.contains)
        else { return nil }
        return L(
            "app_rules.reach.new_profiles_note",
            "New profiles won't get this rule. Tick %1$@ to share it.",
            RuleReachWords.allProfiles
        )
    }
}
