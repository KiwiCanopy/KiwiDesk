import Foundation

/// What the layout-cycle plate shows (#2144): the user's cycle
/// list as a ring and the layout `cycle_mode` landed on, on the
/// screen the stepped Space lays out on. Core names it; the GUI
/// draws, animates and speaks it (#96).
public struct ModeCycleCue: Equatable, Sendable {
    /// The screen the stepped Space lays out on.
    public let display: DisplayID
    /// `mode_cycle` in order: the first entry at 12 o'clock,
    /// clockwise.
    public let cycle: [LayoutMode]
    /// The layout the Space now has — the centre symbol, whose
    /// ring slot stays empty.
    public let current: LayoutMode

    public init(
        display: DisplayID,
        cycle: [LayoutMode],
        current: LayoutMode
    ) {
        self.display = display
        self.cycle = cycle
        self.current = current
    }
}

/// The GUI's hooks for the plate cues Core pays at once — the
/// layout cue (`payModeCue`) and the Space cue (`paySpaceCue`).
@MainActor
final class CueHooks {
    var onModeCue: @MainActor (ModeCycleCue) -> Void = { _ in }
    var onSpaceCue: @MainActor (SpaceSwitchCue) -> Void = { _ in }
}

extension KiwiCore {
    /// The GUI's hook: handed every cue `cycle_mode` pays.
    public var onModeCue: @MainActor (ModeCycleCue) -> Void {
        get { cueHooks.onModeCue }
        set { cueHooks.onModeCue = newValue }
    }

    /// Called once `cycle_mode`'s own write landed, and only then:
    /// the press asked for the plate, so no other mode change
    /// shows it. Stands down where the shelf does (#1787) and
    /// while the setting is off.
    func payModeCue(_ space: SpaceID) {
        guard appWide.modeCue,
            let mode = state.workspaces[space]?.mode,
            let display = state.workspaces.display(of: space),
            !shelfStandsDown(on: display)
        else { return }
        cueHooks.onModeCue(
            ModeCycleCue(
                display: display,
                cycle: modeCycle.list,
                current: mode
            )
        )
    }

    /// `KiwiDesk.set_mode_cue(bool)` (#2144): turns the plate on
    /// or off. App-wide (#1741) and session-only, as every
    /// app-wide verb; no retile.
    func setModeCue(_ args: [JSONValue]) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        setAppWide(persisting: false) { $0.modeCue = on }
        return .ok()
    }
}
