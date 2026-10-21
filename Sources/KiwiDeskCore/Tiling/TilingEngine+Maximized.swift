import AppKit
import CoreGraphics

/// The maximized window's frame (#2448): the screen's whole
/// visible frame with no gaps, laid over the ISSUED frames only.
/// The slots (`calculatedFrames`) keep the window's place in the
/// row, so drag, resize and scroll anchors never read the
/// maximized frame as a slot.
extension TilingEngine {
    /// `frames` with `space`'s maximized window, if it has one,
    /// filling `screen`. Laid out by Monocle over a one-window row,
    /// so an app whose learned maximum is smaller sits centred
    /// (#880) rather than at the corner.
    func fillingMaximized(
        _ frames: [WindowID: CGRect],
        input: (space: Space, tiled: [WindowID], context: LayoutContext),
        on screen: NSScreen,
        state: StateCoordinator
    ) -> [WindowID: CGRect] {
        guard let id = state.maximizedWindow(of: input.space),
            frames[id] != nil
        else { return frames }
        var context = input.context
        context.bounds = visibleBounds(screen)
        context.gaps = Gaps(
            outer: .init(top: 0, bottom: 0, left: 0, right: 0),
            inner: .init(horizontal: 0, vertical: 0)
        )
        context.focused = id
        var filled = frames
        filled[id] =
            LayoutEngine.calculate(
                mode: .monocle,
                windows: [id],
                context: context
            )[id] ?? context.bounds
        return filled
    }
}
