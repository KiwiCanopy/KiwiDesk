import KiwiDeskCore

/// What one display currently holds, in a sentence (#678 Phase 3,
/// turn 13b): "2 Spaces here · Space code is showing".
///
/// Authored once and read twice — the line under the picture says
/// it, and the card speaks it to VoiceOver and shows it on hover.
/// Two copies of one sentence is how a tooltip and a caption come
/// to describe the same display differently.
///
/// **Whole sentences, never a composed one.** The first cut built
/// this by interpolating the count PHRASE into a second frame
/// ("%1$@ · %2$@ is showing"), which asks the translator of the
/// frame to write around a blob they cannot see and the
/// translator of the phrase not to know they are inside one. Each
/// case below is a complete sentence a translator can read
/// (localization audit, 2026-08-04).
///
/// The space id is named — "Space %1$@" — rather than dropped in
/// bare: ids are commonly numeric, and "3 Spaces here · 2 is
/// showing" is two numerals with no noun on either.
///
/// **"is showing" is per display and stays that way.** It comes
/// from `WorkspaceManager.activeSpace(on:)`, the single truth the
/// tiler lays out per display and the bars read — a KiwiDesk
/// space, not a macOS Desktop. It is therefore independent of
/// macOS's "Displays have separate Spaces", which gates the
/// Desktop→profile bindings in Profiles and nothing here.
@MainActor
enum MonitorReadout {
    /// `held` counts what the display HOLDS, which on the main
    /// display includes the spaces that follow main — they are on
    /// that screen right now, and counting only the pinned and
    /// auto-placed chips made a desk where everything follows
    /// main read "0 Spaces here · Space code is showing" on every
    /// card (localization audit, 2026-08-04).
    static func sentence(
        held: Int,
        showing: SpaceID?
    ) -> String {
        // Zero takes its own sentence whatever is showing: a
        // display our own accounting says holds nothing cannot
        // also report "0 Spaces here · Space X is showing", and
        // that pairing is reachable — a space can be up on a
        // display while no configured space resolves to it.
        guard let showing, held > 0 else { return silent(held) }
        switch held {
        case 1:
            return L(
                "monitors.selection.showing.one",
                "1 Space here · Space %1$@ is showing",
                showing.raw
            )
        default:
            return L(
                "monitors.selection.showing.many",
                "%1$d Spaces here · Space %2$@ is showing",
                held,
                showing.raw
            )
        }
    }

    /// A localized PHRASE per count, never "%1$d Space(s)": an
    /// English plural glued to a number reads "1 Spaces" in the
    /// language it was written for and cannot be declined in the
    /// ten it was not.
    private static func silent(_ held: Int) -> String {
        switch held {
        case 0:
            return L("monitors.selection.none", "No Spaces here")
        case 1:
            return L("monitors.selection.one", "1 Space here")
        default:
            return L(
                "monitors.selection.many",
                "%1$d Spaces here",
                held
            )
        }
    }
}
