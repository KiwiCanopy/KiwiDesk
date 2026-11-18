import AppKit
import CoreGraphics

/// The maximized window's frame (#2448): the screen's whole
/// visible frame with no gaps, laid over the ISSUED frames only —
/// a maximized float's included, the one float the set carries
/// (#3036).
/// The slots (`calculatedFrames`) keep the window's place in the
/// row, so drag, resize and scroll anchors never read the
/// maximized frame as a slot.
extension TilingEngine {
    /// `frames` with `space`'s maximized window, if it has one,
    /// filling `screen`; a float's fill is its one issued frame,
    /// anchored on its return frame (#3036). Laid out by Monocle
    /// over a one-window row,
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
            let slot = frames[id] ?? state.maximizedFloatReturn[id]?.frame
        else { return frames }
        var context = input.context
        context.bounds = maximizedBounds(shape, on: screen, slot: slot)
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

    /// The rect a Maximize of `shape` fills on `screen` from the
    /// window's `slot`: the one owner of the fill's bounds, which a
    /// pocket take-out's plate lands on too (#3408).
    func maximizedBounds(
        _ shape: MaximizeShape,
        on screen: NSScreen,
        slot: CGRect
    ) -> CGRect {
        Self.maximizedBounds(shape, screen: visibleBounds(screen), slot: slot)
    }

    /// The rect a Maximize of `shape` fills on a `screen` of AX
    /// visible bounds, from the window's `slot` (#3062): the whole
    /// screen, or its axis whole and the other at the share,
    /// centred on the screen or on the slot and kept inside it.
    /// The one place a share becomes points (#3460): a fraction of
    /// the screen's length, clamped to `fractionRange`, or a length
    /// no longer than that axis, which then fills it.
    nonisolated static func maximizedBounds(
        _ shape: MaximizeShape,
        screen: CGRect,
        slot: CGRect
    ) -> CGRect {
        guard let axis = shape.axis else { return screen }
        switch axis {
        case .height:
            let width = length(shape.share, along: screen.width)
            let centre =
                shape.anchor == .inPlace ? slot.midX : screen.midX
            return CGRect(
                x: Self.kept(width, centre, screen.minX, screen.maxX),
                y: screen.minY,
                width: width,
                height: screen.height
            )
        case .width:
            let height = length(shape.share, along: screen.height)
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

    /// `share` in whole points along an axis `length` long.
    private nonisolated static func length(
        _ share: MaximizeLength,
        along length: CGFloat
    ) -> CGFloat {
        switch share {
        case .fraction(let value):
            let range = MaximizeLength.fractionRange
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            return (length * clamped).rounded()
        case .points(let value):
            return min(value.rounded(), length)
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

/// A screen's Maximize region as Settings reads it (#3460): built
/// only by `KiwiCore.maximizeRegion(on:)` from the bounds hook, so a
/// readout, an overflow line and the Custom unit flip resolve a
/// share as a press does, through `maximizedBounds`.
public struct MaximizeRegion: Equatable, Sendable {
    let bounds: CGRect

    /// The length `share` fills along the other axis of `axis`.
    public func points(
        of share: MaximizeLength,
        axis: MaximizeAxis
    ) -> CGFloat {
        let rect = TilingEngine.maximizedBounds(
            MaximizeShape(axis: axis, share: share),
            screen: bounds,
            slot: bounds
        )
        return axis == .height ? rect.width : rect.height
    }

    /// The share of the screen `points` is along the other axis of
    /// `axis`, the inverse a unit flip takes; nil on an empty axis.
    public func fraction(
        ofPoints points: CGFloat,
        axis: MaximizeAxis
    ) -> Double? {
        let whole = self.points(of: .fraction(1), axis: axis)
        guard whole > 0 else { return nil }
        return Double(points / whole)
    }
}
