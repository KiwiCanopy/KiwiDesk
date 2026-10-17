import Foundation

/// What the Space cue shows (#2143): the Space a switch landed on
/// and its layout, on the screen that switched. Core names it;
/// the GUI draws and speaks it (#96).
public struct SpaceSwitchCue: Equatable, Sendable {
    /// The screen that switched — the only one the plate draws on.
    public let display: DisplayID
    /// The Space's identifier, as the Space Bar draws it.
    public let space: SpaceID
    /// Its layout — the symbol under the identifier.
    public let mode: LayoutMode

    public init(display: DisplayID, space: SpaceID, mode: LayoutMode) {
        self.display = display
        self.space = space
        self.mode = mode
    }
}

extension KiwiCore {
    /// The GUI's hook: handed every cue a Space switch pays.
    public var onSpaceCue: @MainActor (SpaceSwitchCue) -> Void {
        get { cueHooks.onSpaceCue }
        set { cueHooks.onSpaceCue = newValue }
    }

    /// The screen an explicit switch to `target` changes, read
    /// BEFORE the switch activates it; nil where that screen
    /// already shows it, so the switch names nothing.
    func spaceSwitchDisplay(to target: SpaceID) -> DisplayID? {
        guard let display = state.workspaces.display(of: target),
            state.workspaces.activeSpace(on: display) != target
        else { return nil }
        return display
    }

    /// Called by `spaceSwitchRetile` alone, after an explicit
    /// switch, while `space.cue` is on (#2228). Stands down where
    /// `display` draws a Space Bar, which already names the Space,
    /// and where the shelf stands down (#1787).
    func paySpaceCue(on display: DisplayID) {
        guard appWide.spaceCue,
            let space = state.workspaces.activeSpace(on: display),
            let mode = state.workspaces[space]?.mode,
            !spaceBars.shownDisplays.contains(display),
            !shelfStandsDown(on: display)
        else { return }
        cueHooks.onSpaceCue(
            SpaceSwitchCue(display: display, space: space, mode: mode)
        )
    }

    /// `KiwiDesk.set_space_cue(bool)` (#2228): turns the plate on
    /// or off. App-wide (#1741) and session-only, as every app-wide
    /// verb; no retile.
    func setSpaceCue(_ args: [JSONValue]) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        setAppWide(persisting: false) { $0.spaceCue = on }
        return .ok()
    }
}
