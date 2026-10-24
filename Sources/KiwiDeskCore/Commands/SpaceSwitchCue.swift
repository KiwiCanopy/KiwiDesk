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

    /// Called by `spaceSwitchRetile` alone, after an explicit
    /// switch the slide did not play on, while the drawn transition
    /// is Show the Space (#2524) — on every screen, a Space Bar or
    /// not, save where the shelf stands down (#1787) and a switch
    /// the Space Bar picked, whose chip already named the Space.
    func paySpaceCue(on display: DisplayID) {
        guard drawnSpaceTransition == .show,
            !cueHooks.spaceBarPicking,
            let space = state.workspaces.activeSpace(on: display),
            let mode = state.workspaces[space]?.mode,
            !shelfStandsDown(on: display)
        else { return }
        cueHooks.onSpaceCue(
            SpaceSwitchCue(display: display, space: space, mode: mode)
        )
    }

    /// Runs a Space Bar pick — a chip, a glyph, a list row — whose
    /// switch pays no Space cue; the slide still plays.
    func fromSpaceBar(_ body: () -> Void) {
        let outer = cueHooks.spaceBarPicking
        cueHooks.spaceBarPicking = true
        defer { cueHooks.spaceBarPicking = outer }
        body()
    }

    /// `KiwiDesk.set_space_transition(name)` (#2524): `slide`,
    /// `show` or `none`. App-wide (#1741) and session-only, as
    /// every app-wide verb; read at each switch, so no retile.
    func setSpaceTransition(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let style = SpaceTransition(rawValue: raw)
        else { return .expected(SpaceTransition.self) }
        setAppWide(persisting: false) { $0.spaceTransition = style }
        return .ok()
    }

    /// `KiwiDesk.set_space_slide_duration(ms)` (#2524): the slide's
    /// pace, clamped into its band; read at each press.
    func setSpaceSlideDuration(_ args: [JSONValue]) -> CommandResponse {
        guard let ms = args.first?.intValue else {
            return .fail("expected milliseconds")
        }
        setAppWide(persisting: false) {
            $0.spaceSlideDuration = AppWideSettings.clampedSlideDuration(ms)
        }
        return .ok()
    }
}
