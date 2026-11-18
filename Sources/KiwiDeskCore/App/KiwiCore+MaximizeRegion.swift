import AppKit

extension KiwiCore {
    /// The Maximize region of the screen `display` names, read
    /// through the one bounds hook (#531) as a press reads it; nil
    /// where no such screen is connected (#3460).
    @MainActor
    public func maximizeRegion(on display: DisplayID?) -> MaximizeRegion? {
        guard let display,
            let screen = TilingEngine.screen(for: display)
        else { return nil }
        return MaximizeRegion(bounds: tiler.visibleBounds(screen))
    }
}
