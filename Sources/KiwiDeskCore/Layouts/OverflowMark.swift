import CoreGraphics

/// The "+n" mark on the edge window at each end of a run that
/// hides windows (#2235 ▸ Ruling — the overflow mark): derived
/// from a `RunCover`, never stored, so any layout that records a
/// cover gets its marks. Geometry is in AX coordinates (y down),
/// the engine's own.
public struct OverflowMark: Sendable, Equatable {
    /// Which end of its run the mark sits on.
    public enum End: Sendable, Equatable, CaseIterable {
        case top, bottom, left, right

        /// Whether the count's text runs along the edge, so the
        /// mark is a pill; across it, a circle.
        public var isPill: Bool { self == .top || self == .bottom }
    }

    public let space: SpaceID
    /// The shown window at that end, which the mark rides.
    public let anchor: WindowID
    public let end: End
    /// That end's hidden windows, nearest the edge first — the
    /// order one focus step at a time brings them in.
    public let windows: [WindowID]
    /// The layout bounds the run was laid in, outer gap included.
    public let bounds: CGRect

    public var count: Int { windows.count }

    /// Overlay key: one run end, named by its Space, its zone's
    /// place and its end — never the anchor, which a scroll step
    /// changes, so a step re-anchors the mark rather than minting
    /// a panel (#2026's steady-path rule).
    public struct Key: Hashable, Sendable {
        public let space: SpaceID
        public let end: End
        public let zoneX: Int
        public let zoneY: Int
    }

    /// The zone's origin, which a scroll leaves in place.
    public let zoneOrigin: CGPoint

    public var key: Key {
        Key(
            space: space,
            end: end,
            zoneX: Int(zoneOrigin.x.rounded()),
            zoneY: Int(zoneOrigin.y.rounded())
        )
    }

    /// One mark per run end that hides windows.
    public static func marks(of cover: RunCover) -> [OverflowMark] {
        cover.runs.flatMap { run -> [OverflowMark] in
            guard let first = run.shown.first, let last = run.shown.last
            else { return [] }
            let vertical = run.zone.vertical
            var out: [OverflowMark] = []
            if !run.hiddenBefore.isEmpty {
                out.append(
                    OverflowMark(
                        space: cover.space,
                        anchor: first,
                        end: vertical ? .top : .left,
                        windows: Array(run.hiddenBefore.reversed()),
                        bounds: run.bounds,
                        zoneOrigin: run.zone.region.origin
                    )
                )
            }
            if !run.hiddenAfter.isEmpty {
                out.append(
                    OverflowMark(
                        space: cover.space,
                        anchor: last,
                        end: vertical ? .bottom : .right,
                        windows: Array(run.hiddenAfter),
                        bounds: run.bounds,
                        zoneOrigin: run.zone.region.origin
                    )
                )
            }
            return out
        }
    }

    /// The mark's depth across its edge, and a pill's height.
    public static let depth: CGFloat = 18
    /// A pill's room either side of its count.
    public static let pillPad: CGFloat = 7
    /// A circle's room either side of its count.
    public static let circlePad: CGFloat = 2

    /// The mark's size for a count `textWidth` points wide: as
    /// shallow across the edge as horizontal text allows — a pill
    /// along a top or bottom edge, a circle sized to the text on a
    /// side (owner ruling, 2026-10-22).
    public static func size(end: End, textWidth: CGFloat) -> CGSize {
        if end.isPill {
            let width = max(depth, (textWidth + 2 * pillPad).rounded(.up))
            return CGSize(width: width, height: depth)
        }
        let side = max(depth, (textWidth + 2 * circlePad).rounded(.up))
        return CGSize(width: side, height: side)
    }

    /// The mark's frame on `anchor`: centred along the edge, its
    /// outer edge flush with `bounds` so it fills the outer gap
    /// and reaches onto the window by its depth less that gap —
    /// never past `bounds`, and never off the window where the gap
    /// is deeper than the mark.
    public static func frame(
        end: End,
        size: CGSize,
        anchor: CGRect,
        bounds: CGRect
    ) -> CGRect {
        var rect = CGRect(origin: .zero, size: size)
        switch end {
        case .top:
            rect.origin.y = min(
                anchor.minY,
                max(bounds.minY, anchor.minY - size.height)
            )
        case .bottom:
            let maxY = max(
                anchor.maxY,
                min(bounds.maxY, anchor.maxY + size.height)
            )
            rect.origin.y = maxY - size.height
        case .left:
            rect.origin.x = min(
                anchor.minX,
                max(bounds.minX, anchor.minX - size.width)
            )
        case .right:
            let maxX = max(
                anchor.maxX,
                min(bounds.maxX, anchor.maxX + size.width)
            )
            rect.origin.x = maxX - size.width
        }
        if end.isPill {
            rect.origin.x = clamped(
                anchor.midX - size.width / 2,
                size.width,
                bounds.minX,
                bounds.maxX
            )
        } else {
            rect.origin.y = clamped(
                anchor.midY - size.height / 2,
                size.height,
                bounds.minY,
                bounds.maxY
            )
        }
        return rect
    }

    private static func clamped(
        _ origin: CGFloat,
        _ length: CGFloat,
        _ low: CGFloat,
        _ high: CGFloat
    ) -> CGFloat {
        guard high - low >= length else { return origin }
        return min(max(origin, low), high - length)
    }
}
