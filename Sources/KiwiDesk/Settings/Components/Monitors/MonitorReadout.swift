import KiwiDeskCore

/// Monitor space occupancy and active space description —
/// authored once, read twice (caption + VoiceOver/hover). WHOLE
/// sentences, never a composed frame: interpolating a count
/// phrase into a second frame asks a translator to write around
/// a blob they cannot see (l10n audit 2026-08-04). "is showing"
/// is `WorkspaceManager.activeSpace(on:)` — per display,
/// independent of macOS "separate Spaces" (#678 Phase 3).
@MainActor
enum MonitorReadout {
    /// Formatted status sentence. `held` counts what the display
    /// HOLDS, follows-main spaces included — counting only pinned
    /// chips made an everything-follows-main desk read "0 Spaces
    /// here" on every card (l10n audit 2026-08-04).
    static func sentence(
        held: Int,
        showing: SpaceID?
    ) -> String {
        // Zero takes its own sentence whatever is showing: "0
        // Spaces here · Space X is showing" is reachable — a
        // space can be up on a display no configured space
        // resolves to.
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

    /// Localized count string — a PHRASE per count, never
    /// "%1$d Space(s)": an English plural glued to a number cannot
    /// be declined in the ten languages it was not written for.
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
