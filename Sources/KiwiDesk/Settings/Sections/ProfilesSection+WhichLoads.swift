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
/// The verdict ASKS THE ENGINE (gui.md) — `KiwiCore.profileVerdict`
/// carries the SAME precedence the live paths use, bindings
/// included. An earlier cut asked `ProfileManager.match` alone and
/// so answered only the display half of the rule: with a Desktop
/// bound it named the profile that would load on a *monitor*
/// change while a different one was actually on screen, and the
/// card that configures those bindings sits directly below this
/// one. A preview that models part of an engine's rule must say
/// which part; this one models all of it.
///
/// The verdict is read from the model's snapshot, never queried
/// here: it costs a directory scan plus a decode per profile.
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

    /// Both halves of the precedence, in the order it applies —
    /// a rule sentence that mentioned only screen counts would be
    /// wrong for anyone who has bound a Desktop, and the card
    /// below this one is where they bound it.
    private var rulesSentence: String {
        L(
            "profiles.which_loads.rule",
            "A profile bound to the active Desktop loads first. "
                + "Otherwise KiwiDesk picks the profile whose "
                + "screen count matches, preferring the one "
                + "marked default."
        )
    }

    /// "Right now: 3 screens → Desk", with the rule that fired —
    /// they are different promises. The DEFAULT is the durable
    /// one: an exact match compares the fingerprint set, so
    /// swapping in a different monitor of the same count drops
    /// it, while a count default only asks how many screens
    /// there are.
    private var verdictSentence: String {
        // Count and verdict from ONE snapshot. Reading the count
        // live beside a snapshotted verdict lets the sentence
        // name a profile that matched a different display set —
        // "2 screens → Desk (these exact monitors)" about a
        // one-screen match.
        //
        // The count phrase, never a bare `%1$d screens` — that
        // frame renders "1 screens" on a one-display Mac, and no
        // catalog can repair a frame.
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
