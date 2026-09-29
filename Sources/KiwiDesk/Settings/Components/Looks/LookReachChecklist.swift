import KiwiDeskCore
import SwiftUI

/// The shared look's checklist (#1752): All profiles, then one box
/// per profile — the profiles wearing the look this page shows, as
/// App Rules' checklist reads. The edited profile's box is ticked
/// and locked; on a following profile's page the others follow or
/// keep their own, and on an own profile's page they grey, since
/// the look shown there is no one else's (owner ruling 2026-09-29).
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

    /// Whether this page shows the shared look — else its own,
    /// which nobody else can join.
    private var editedFollows: Bool { follows[edited] == true }

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
        .disabled(everyoneFollows || !editedFollows)
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
                    // This profile always wears the look shown here.
                    get: { profile == edited || follows[profile] == true },
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
            .disabled(profile == edited || !editedFollows)
            .help(profile == edited ? lockedHelp : "")
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

    private var lockedHelp: String {
        L(
            "looks.reach.locked_help",
            "You're editing this profile. To change whether it shares "
                + "the look, open another profile that does."
        )
    }

    private var notes: [String] {
        guard editedFollows else {
            return [
                L(
                    "looks.reach.own_page_note",
                    "This profile keeps its own look, so no other profile "
                        + "can share it. To share a look, open a profile "
                        + "that uses the shared one."
                )
            ]
        }
        guard profiles.contains(where: { follows[$0] == false }) else {
            return []
        }
        return [
            L(
                "looks.reach.replace_own_note",
                "Ticking a profile with its own look replaces it with "
                    + "the shared one."
            )
        ]
    }
}
