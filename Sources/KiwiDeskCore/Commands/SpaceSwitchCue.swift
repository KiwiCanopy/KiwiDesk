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

    /// Called after a switch the slide would play on, where it did
    /// not: on Show the Space, or Slide under Reduce Motion. Stands
    /// down where `display` draws a Space Bar, which already names
    /// the Space, and where the shelf stands down (#1787).
    func paySpaceCue(on display: DisplayID) {
        let style = tiler.settings.animations.spaceChange
        guard
            style == .cue
                || (style == .slide && spaceSlide.reduceMotion()),
            let space = state.workspaces.activeSpace(on: display),
            let mode = state.workspaces[space]?.mode,
            !spaceBars.shownDisplays.contains(display),
            !shelfStandsDown(on: display)
        else { return }
        cueHooks.onSpaceCue(
            SpaceSwitchCue(display: display, space: space, mode: mode)
        )
    }
}
