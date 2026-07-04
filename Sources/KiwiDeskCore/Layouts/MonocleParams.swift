import CoreGraphics
import Foundation

/// Monocle tuning: orientation (which focus axis cycles
/// through the windows) and the indicator bar listing them.
public struct MonocleParams: Sendable, Equatable {
    /// The bar's settings live in their own type (and their
    /// own `bar` object in profile JSON); the alias keeps
    /// call sites reading as `MonocleParams.Bar`.
    public typealias Bar = MonocleBarParams

    /// Which focus axis cycles through the monocle windows —
    /// and, with it, which edges the indicator bar may sit on.
    public enum Orientation: String, Sendable, Codable {
        /// `focus("left"/"right")` cycles; bar on top/bottom.
        case horizontal
        /// `focus("up"/"down")` cycles; bar on left/right.
        case vertical
    }

    public var orientation: Orientation = .horizontal
    public var bar = Bar()

    public init() {}
}

// MARK: - Geometry

extension MonocleParams {
    /// `bar.position` clamped to the orientation's allowed
    /// edges: a mismatch falls back to the orientation's
    /// default edge (top / left) instead of erroring.
    public var resolvedBarPosition: Bar.Position {
        switch orientation {
        case .horizontal:
            return bar.position.isHorizontalEdge
                ? bar.position : .top
        case .vertical:
            return bar.position.isHorizontalEdge
                ? .left : bar.position
        }
    }

    /// The strip the indicator bar occupies, carved from the
    /// resolved edge of `usable` (AX coordinates, y grows
    /// downward). Nil while the bar is off.
    public func barFrame(in usable: CGRect) -> CGRect? {
        guard bar.enabled else { return nil }
        switch resolvedBarPosition {
        case .top, .bottom:
            let depth = min(bar.thickness, usable.height)
            return CGRect(
                x: usable.minX,
                y: resolvedBarPosition == .top
                    ? usable.minY
                    : usable.maxY - depth,
                width: usable.width,
                height: depth
            )
        case .left, .right:
            let depth = min(bar.thickness, usable.width)
            return CGRect(
                x: resolvedBarPosition == .left
                    ? usable.minX
                    : usable.maxX - depth,
                y: usable.minY,
                width: depth,
                height: usable.height
            )
        }
    }

    /// The window area: `usable` minus the bar strip and one
    /// inner gap between strip and window.
    public func windowFrame(
        in usable: CGRect,
        inner: Gaps.Inner
    ) -> CGRect {
        guard let bar = barFrame(in: usable) else {
            return usable
        }
        var frame = usable
        switch resolvedBarPosition {
        case .top:
            let cut = bar.height + inner.vertical
            frame.origin.y += cut
            frame.size.height = max(usable.height - cut, 0)
        case .bottom:
            let cut = bar.height + inner.vertical
            frame.size.height = max(usable.height - cut, 0)
        case .left:
            let cut = bar.width + inner.horizontal
            frame.origin.x += cut
            frame.size.width = max(usable.width - cut, 0)
        case .right:
            let cut = bar.width + inner.horizontal
            frame.size.width = max(usable.width - cut, 0)
        }
        return frame
    }
}

// MARK: - Codable

extension MonocleParams: Codable {
    private enum CodingKeys: String, CodingKey {
        case orientation
        case bar
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = MonocleParams()
        orientation =
            try container.decodeIfPresent(
                Orientation.self,
                forKey: .orientation
            ) ?? defaults.orientation
        bar =
            try container.decodeIfPresent(
                Bar.self,
                forKey: .bar
            ) ?? defaults.bar
    }
}
