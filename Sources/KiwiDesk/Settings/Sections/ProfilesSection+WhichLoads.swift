import KiwiDeskCore
import SwiftUI

/// Profile resolution readout explaining which profile loads
/// (`KiwiCore.profileVerdict`, `ProfileManager.match`, `gui.md`,
/// #678 turn 13a).
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
            "A profile bound to the active Desktop loads first. "
                + "Otherwise KiwiDesk picks the profile whose "
                + "screen count matches, preferring the one "
                + "marked default."
        )
    }

    /// Explains active profile resolution verdict for live monitors
    /// (#36, #96).
    private var verdictSentence: String {
        // Count and verdict from ONE snapshot: reading the count
        // live beside a snapshotted verdict lets the sentence name
        // a profile that matched a different display set. The
        // count phrase, never a bare `%1$d screens` — that frame
        // renders "1 screens" and no catalog can repair a frame.
        let resolution = model.profileResolution
        let screens = screensPhrase(resolution.screens)
        switch resolution.verdict {
        case .boundToDesktop(let name, let desktop):
            return L(
                "profiles.which_loads.bound",
                "Right now: Desktop %1$d → %2$@ (bound below, "
                    + "which outranks the screen count).",
                desktop,
                name
            )
        case .exactMonitors(let name):
            return L(
                "profiles.which_loads.exact",
                "Right now: %1$@ → %2$@ (these exact monitors).",
                screens,
                name
            )
        case .countDefault(let name):
            return L(
                "profiles.which_loads.count_default",
                "Right now: %1$@ → %2$@ (the default for this "
                    + "screen count).",
                screens,
                name
            )
        case .builtInStandard(let name):
            // Named, not "a built-in layout": the name is what
            // the Presets card offers, so the two surfaces say
            // the same word. Core carries the stable English
            // name; the GUI localizes it (#96).
            return L(
                "profiles.which_loads.standard",
                "Right now: %1$@ → the built-in %2$@ (no saved "
                    + "profile matches).",
                screens,
                standardDisplayName(name)
            )
        case .placementOnlyStandard(let name, let active):
            // A Lua-owned config keeps owning the tiling, so the
            // built-in only steers WHERE spaces sit. Saying "the
            // built-in X loads" here would claim it replaced a
            // hand-written config, which is the promise #36
            // makes in the other direction.
            guard let active else {
                return L(
                    "profiles.which_loads.placement_only",
                    "Right now: %1$@ → your Lua config keeps the "
                        + "layout; the built-in %2$@ only places "
                        + "Spaces on screens.",
                    screens,
                    standardDisplayName(name)
                )
            }
            return L(
                "profiles.which_loads.placement_only_profile",
                "Right now: %1$@ → %2$@ keeps the layout; the "
                    + "built-in %3$@ only places Spaces on "
                    + "screens.",
                screens,
                active,
                standardDisplayName(name)
            )
        case .none:
            return L(
                "profiles.which_loads.none",
                "Right now: %1$@ → no profile and no built-in "
                    + "layout match.",
                screens
            )
        }
    }
}
