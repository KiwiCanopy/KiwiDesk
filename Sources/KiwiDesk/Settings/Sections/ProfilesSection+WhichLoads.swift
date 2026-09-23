import KiwiDeskCore
import SwiftUI

/// Profile resolution readout explaining which profile loads
/// (`KiwiCore.profileVerdict`, `ProfileManager.match`, `gui.md`,
/// #678 turn 13a).
extension ProfilesSection {
    @ViewBuilder var whichProfileLoads: some View {
        SettingsSection(SettingsCatalog.profiles.whichProfileLoads) {
            Text(rulesSentence)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(verdictSentence)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The card is a live DIAGNOSTIC, so its flow line states
    /// only the premise the verdict below is read against
    /// (#1241). The ladder itself is a concept and lives in the
    /// `?` — `ui-patterns.md` ▸ a concept goes in the help. The
    /// old line stated two of the four rungs as if they were
    /// the rule, which is the half-a-rule-stated-confidently
    /// shape `docs/design-decisions.md` rules against.
    private var rulesSentence: String {
        L(
            "profiles.which_loads.rule",
            "KiwiDesk runs one profile across your whole desk."
        )
    }

    /// The whole ladder, numbered in its order (#1609) — the
    /// Saved profiles header's one `?`, which this card's status
    /// line narrates a rung of. The binding card is named by
    /// interpolation, never quoted (#818).
    var ladderHelp: String {
        L(
            "profiles.saved.help",
            "KiwiDesk loads the first of these that applies:\n"
                + "1. A profile bound to the Desktop on your main "
                + "screen for the connected screen setup.\n"
                + "2. A profile bound to that Desktop for all "
                + "screen setups.\n"
                + "3. The profile that holds the connected screen "
                + "setup.\n"
                + "4. The profile marked default for this many "
                + "screens.\n"
                + "5. A built-in layout.\n\n"
                + "Bind profiles to Desktops in %1$@, below. A "
                + "binding counts only for a profile saved for as "
                + "many screens as are connected.",
            L("desktops.title", "Profiles per macOS Desktop")
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
        case .boundToDesktop(let name, let desktop, let setup, _):
            // The rung the binding took (#1609): the user set a
            // scope, not a count, so the scope is what it names.
            return setup == nil
                ? L(
                    "profiles.which_loads.bound_all",
                    "Right now: Desktop %1$d → %2$@ (bound for all "
                        + "screen setups).",
                    desktop,
                    name
                )
                : L(
                    "profiles.which_loads.bound_setup",
                    "Right now: Desktop %1$d → %2$@ (bound for this "
                        + "screen setup).",
                    desktop,
                    name
                )
        case .exactMonitors(let name):
            return L(
                "profiles.which_loads.holds",
                "Right now: %1$@ → %2$@ (it holds this screen "
                    + "setup).",
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
