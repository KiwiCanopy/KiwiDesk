import KiwiDeskCore

/// Monitor space occupancy and active space description
/// (`WorkspaceManager.activeSpace(on:)`, #678 Phase 3).
@MainActor
enum MonitorReadout {
    /// Formatted status sentence showing held and active spaces.
    static func sentence(
        held: Int,
        showing: SpaceID?
    ) -> String {
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

    /// Localized count string when no active space is shown.
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
