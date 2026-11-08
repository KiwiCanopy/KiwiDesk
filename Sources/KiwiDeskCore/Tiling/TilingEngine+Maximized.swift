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
            let shape = state.maximizedShape(of: input.space),
            let slot = frames[id]
        else { return frames }
        var context = input.context
        context.bounds = Self.maximizedBounds(
            shape,
            screen: visibleBounds(screen),
            slot: slot
        )
        context.gaps = .none
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

    /// The rect a Maximize of `shape` fills on a `screen` of AX
    /// visible bounds, from the window's `slot` (#3062): the whole
    /// screen, or its axis whole and the other at the share,
    /// centred on the screen or on the slot and kept inside it.
    nonisolated static func maximizedBounds(
        _ shape: MaximizeShape,
        screen: CGRect,
        slot: CGRect
    ) -> CGRect {
        guard let axis = shape.axis else { return screen }
        let share = min(
            max(shape.share, MaximizeShape.shareRange.lowerBound),
            MaximizeShape.shareRange.upperBound
        )
        switch axis {
        case .height:
            let width = (screen.width * share).rounded()
            let centre =
                shape.anchor == .inPlace ? slot.midX : screen.midX
            return CGRect(
                x: Self.kept(width, centre, screen.minX, screen.maxX),
                y: screen.minY,
                width: width,
                height: screen.height
            )
        case .width:
            let height = (screen.height * share).rounded()
            let centre =
                shape.anchor == .inPlace ? slot.midY : screen.midY
            return CGRect(
                x: screen.minX,
                y: Self.kept(height, centre, screen.minY, screen.maxY),
                width: screen.width,
                height: height
            )
        }
    }

    /// The start of a `length` centred on `centre`, moved back
    /// inside `low...high`.
    private nonisolated static func kept(
        _ length: CGFloat,
        _ centre: CGFloat,
        _ low: CGFloat,
        _ high: CGFloat
    ) -> CGFloat {
        min(max(centre - length / 2, low), high - length)
    }
}
