import KiwiDeskCore
import SwiftUI

/// **Which profile loads** (#678 turn 13a) — the rule, and what
/// it resolves to right now.
///
/// The rule was never written down in the GUI: a user could read
/// the list, the badges and the footer and still not know why
/// *this* profile is the one that came up. So the card states it,
/// and then answers it for the live machine.
///
/// The verdict ASKS THE ENGINE (gui.md): `ProfileManager.match`
/// is the same query the monitor-change path resolves with, so
/// this card cannot drift from what actually loads. Nothing here
/// re-implements exact-set-then-count-default beside the drawing
/// of it — the one thing it adds is the `.none` arm's name for
/// the built-in Standard, which the engine composes rather than
/// matches.
extension ProfilesSection {
    @ViewBuilder var whichProfileLoads: some View {
        SettingsSection(
            SettingsCatalog.profiles.whichProfileLoads
        ) {
            Text(rulesSentence)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(verdictSentence)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rulesSentence: String {
        L(
            "profiles.which_loads.rule",
            "KiwiDesk picks the profile whose screen count "
                + "matches, preferring the one marked default."
        )
    }

    /// "Right now: 3 screens → Desk", with the reason the match
    /// fired — an exact monitor match and a count default are
    /// different promises, and only the first survives plugging a
    /// different monitor of the same count in.
    private var verdictSentence: String {
        let screens = model.displays.count
        switch model.core.profiles.match(
            fingerprints: model.displays.map(\.fingerprint)
        ) {
        case .exact(let profile):
            return L(
                "profiles.which_loads.exact",
                "Right now: %1$d screens → %2$@ (these exact "
                    + "monitors).",
                screens,
                profile.name
            )
        case .countDefault(let profile):
            return L(
                "profiles.which_loads.count_default",
                "Right now: %1$d screens → %2$@ (the default "
                    + "for this screen count).",
                screens,
                profile.name
            )
        case .none:
            return standardVerdict(screens: screens)
        }
    }

    /// No saved profile covers the live screens, so a built-in
    /// Standard composes. Named, not called "a built-in layout":
    /// the name is what the Presets card offers, so the two
    /// surfaces say the same word.
    private func standardVerdict(screens: Int) -> String {
        guard
            let standard = StandardProfiles.standard(
                for: screens
            )
        else {
            return L(
                "profiles.which_loads.none",
                "Right now: %1$d screens → no profile and no "
                    + "built-in layout match.",
                screens
            )
        }
        return L(
            "profiles.which_loads.standard",
            "Right now: %1$d screens → the built-in %2$@ "
                + "(no saved profile matches).",
            screens,
            standard.displayName
        )
    }
}
