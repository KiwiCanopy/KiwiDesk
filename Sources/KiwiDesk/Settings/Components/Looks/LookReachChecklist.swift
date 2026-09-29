import KiwiDeskCore
import SwiftUI

/// The shared look's checklist (#1752): All profiles, then one box
/// per profile. A tick means that profile follows the shared look;
/// every box stays live, the edited profile's included — its box is
/// the switch — and All profiles is ticked exactly when every
/// profile follows.
struct LookReachChecklist: View {
    @ObservedObject var model: SettingsModel
    let edited: String

    private var follows: [String: Bool] { model.lookFollows }
    private var profiles: [String] {
        model.profileMenuOrder.filter { follows[$0] != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                L(
                    "looks.reach.subject",
                    "Profiles that use the shared look"
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
            allProfiles
            Divider()
            ForEach(profiles, id: \.self) { profileRow($0) }
            ForEach(notes, id: \.self) { note in
                Text(note)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(minWidth: 260, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L("looks.reach.popover", "Where the shared look applies")
        )
    }

    private var everyoneFollows: Bool {
        profiles.allSatisfy { follows[$0] == true }
    }

    /// Ticking it moves every profile onto the shared look; it greys
    /// while ticked, since unticking everyone at once is no choice
    /// anyone makes.
    private var allProfiles: some View {
        Toggle(
            RuleReachWords.allProfiles,
            isOn: Binding(
                get: { everyoneFollows },
                set: { if $0 { model.setLookFollowsAll() } }
            )
        )
        .toggleStyle(.checkbox)
        .disabled(everyoneFollows)
        .help(
            L(
                "looks.reach.all_help",
                "Every profile uses the shared look. Untick one to "
                    + "give it its own."
            )
        )
    }

    private func profileRow(_ profile: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Toggle(
                isOn: Binding(
                    get: { follows[profile] == true },
                    set: { model.setLookFollows(profile, $0) }
                )
            ) {
                HStack(spacing: 4) {
                    Text(profile)
                    if let mark = mark(profile) {
                        Text(mark).foregroundStyle(SettingsTheme.ink3)
                    }
                }
            }
            .toggleStyle(.checkbox)
            .help(profile == edited ? editedHelp : "")
            if follows[profile] == false {
                Text(L("looks.reach.own", "Own look"))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(.leading, 20)
            }
        }
    }

    private func mark(_ profile: String) -> String? {
        if profile == edited {
            return L("app_rules.reach.this_profile", "this profile")
        }
        if profile == model.activeProfile {
            return L("app_rules.reach.loaded", "loaded")
        }
        return nil
    }

    private var editedHelp: String {
        follows[edited] == true
            ? L(
                "looks.reach.this_help.shared",
                "Untick to give this profile its own copy of the look."
            )
            : L(
                "looks.reach.this_help.own",
                "Tick to use the shared look here instead of this "
                    + "profile's own."
            )
    }

    private var notes: [String] {
        var result: [String] = []
        if profiles.contains(where: { follows[$0] == false }) {
            result.append(
                L(
                    "looks.reach.replace_own_note",
                    "Ticking a profile with its own look replaces it "
                        + "with the shared one."
                )
            )
        }
        if follows[edited] == false {
            result.append(
                L(
                    "looks.reach.not_this_note",
                    "This profile has its own look, so a profile you "
                        + "tick gets the shared look, not the one shown "
                        + "here."
                )
            )
        }
        return result
    }
}
