import KiwiDeskCore
import SwiftUI

/// The "Applies to" popover (#1393): All profiles, then one box
/// per profile. The edited profile is always ticked; under All
/// profiles its followers are ticked and greyed, and a profile
/// with its own value stays tickable, which drops that value.
struct RuleReachChecklist: View {
    @ObservedObject var model: SettingsModel
    let family: RuleFamily
    let app: String
    let value: String

    var body: some View {
        if let reading {
            content(reading)
                .padding(12)
                .frame(minWidth: 260, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(
                    L(
                        "app_rules.reach.popover",
                        "Where %1$@'s rule applies",
                        name
                    )
                )
        }
    }

    private var reading: RuleReachReading? {
        switch family {
        case .space: model.spaceReach(app)
        case .float:
            model.floatReach(app, describe: SettingsModel.floatWords)
        }
    }

    private var name: String {
        KeybindingCatalog.displayName(forBundleID: app)
    }

    private func content(_ reading: RuleReachReading) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                L("app_rules.reach.subject", "%1$@ · %2$@", name, value)
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
            allProfiles(reading)
            Divider()
            ForEach(reading.profiles, id: \.self) { profile in
                profileRow(profile, reading)
            }
            ForEach(reading.unreadable, id: \.self) { profile in
                unreadableRow(profile)
            }
            if let note = note(reading) {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func allProfiles(_ reading: RuleReachReading) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Toggle(
                RuleReachWords.allProfiles,
                isOn: Binding(
                    get: { reading.shared },
                    set: { model.setAllProfiles(family, app, $0) }
                )
            )
            .toggleStyle(.checkbox)
            caption(
                L(
                    "app_rules.reach.all_caption",
                    "Includes profiles you create later."
                ),
                warning: false
            )
        }
    }

    private func profileRow(
        _ profile: String,
        _ reading: RuleReachReading
    ) -> some View {
        let own = reading.own[profile]
        let leftOut = reading.leftOut.contains(profile)
        let locked = profile == reading.editing
        let follows = reading.shared && own == nil && !leftOut
        return VStack(alignment: .leading, spacing: 1) {
            Toggle(
                isOn: Binding(
                    get: { reading.users.contains(profile) },
                    set: { model.setProfile(family, app, profile, $0) }
                )
            ) {
                HStack(spacing: 4) {
                    Text(profile)
                    if let mark = mark(profile, reading) {
                        Text(mark).foregroundStyle(SettingsTheme.ink3)
                    }
                }
            }
            .toggleStyle(.checkbox)
            .disabled(locked || follows)
            .help(hint(locked: locked, follows: follows))
            if let own {
                caption(
                    reading.ownIsShared.contains(profile)
                        ? L(
                            "app_rules.reach.shared_value",
                            "⚠ Shared rule: %1$@",
                            own
                        )
                        : L("app_rules.reach.own", "⚠ Own rule: %1$@", own),
                    warning: true
                )
            } else if leftOut {
                caption(
                    L("app_rules.reach.left_out", "⚠ Left out of this rule"),
                    warning: true
                )
            }
        }
    }

    private func unreadableRow(_ profile: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Toggle(profile, isOn: .constant(false))
                .toggleStyle(.checkbox)
                .disabled(true)
            caption(
                L(
                    "app_rules.reach.unreadable",
                    "⚠ Can't be read — see %1$@.",
                    SettingsDestination.profiles.title
                ),
                warning: true
            )
        }
    }

    private func caption(_ text: String, warning: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(
                warning ? SettingsTheme.warningInk : SettingsTheme.ink3
            )
            .padding(.leading, 20)
    }

    private func mark(_ profile: String, _ reading: RuleReachReading)
        -> String?
    {
        if profile == reading.editing {
            return L("app_rules.reach.this_profile", "this profile")
        }
        if profile == reading.loaded {
            return L("app_rules.reach.loaded", "loaded")
        }
        return nil
    }

    private func hint(locked: Bool, follows: Bool) -> String {
        if locked {
            return L(
                "app_rules.reach.locked_help",
                "You're editing this profile. To remove the rule "
                    + "here, use the trash."
            )
        }
        return follows
            ? L(
                "app_rules.reach.follows_help",
                "Follows %1$@.",
                RuleReachWords.allProfiles
            )
            : ""
    }

    private func note(_ reading: RuleReachReading) -> String? {
        if reading.shared {
            return L(
                "app_rules.reach.leave_out_note",
                "To leave a profile out, untick %1$@ first.",
                RuleReachWords.allProfiles
            )
        }
        guard reading.profiles.allSatisfy(reading.users.contains) else {
            return nil
        }
        return L(
            "app_rules.reach.new_profiles_note",
            "New profiles won't get this rule. Tick %1$@ to share it.",
            RuleReachWords.allProfiles
        )
    }
}
