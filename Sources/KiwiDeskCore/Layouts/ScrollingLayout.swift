import CoreGraphics

/// Scrolling column/row layout (#239, #66, #966, #878, #139, #142).
public struct ScrollingLayout: LayoutSystem {
    /// Visible sliver of a slot scrolled past screen edge (#142).
    static let edgePeek: CGFloat =
        WindowServerFacts.visibilityFloor + 8

    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }

        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.axisIsHorizontal

        if windows.count == 1, let only = windows.first {
            return [
                only: context.sizeBounds[only]?
                    .centered(
                        in: area,
                        generalizing:
                            !context.probesBeyondBounds
                    ) ?? area
            ]
        }

        let metrics = Self.metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        let offset = Self.offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollRest,
            focus: context.focused,
            along: metrics.along,
            size: metrics.focusedSpan,
            rowLength: metrics.rowLength,
            focusedPos: metrics.focusedPos
        )

        return frames(
            windows: windows,
            area: area,
            horizontal: horizontal,
            offset: offset,
            metrics: metrics,
            neighbors: context.screenNeighbors
        )
    }

    /// Row geometry shared between layout calculation and viewport rest
    /// (#141, #677).
    struct Metrics {
        let along: CGFloat
        let size: CGFloat
        let spans: [CGFloat]
        let positions: [CGFloat]
        let rowLength: CGFloat
        let focusedPos: CGFloat?
        let focusedSpan: CGFloat
    }

    static func metrics(
        for windows: [WindowID],
        context: LayoutContext,
        area: CGRect,
        horizontal: Bool
    ) -> Metrics {
        let gap =
            horizontal
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let along = horizontal ? area.width : area.height
        let resolved = context.scrolling.slotSize.resolved(
            along: along,
            horizontal: horizontal
        )
        let size = min(along, max(resolved, context.minWindowSize))
        let spans = windows.map { window -> CGFloat in
            let bound = context.sizeBounds[window]
            let generalizing = !context.probesBeyondBounds
            let consumed =
                horizontal
                ? bound?.consumedWidth(
                    asking: size,
                    generalizing: generalizing
                )
                : bound?.consumedHeight(
                    asking: size,
                    generalizing: generalizing
                )
            return consumed ?? size
        }
        var positions: [CGFloat] = []
        positions.reserveCapacity(spans.count)
        var cursor: CGFloat = 0
        for span in spans {
            positions.append(cursor)
            cursor += span + gap
        }
        let rowLength = max(cursor - gap, 0)
        let focusedIndex = context.focused.flatMap {
            windows.firstIndex(of: $0)
        }
        return Metrics(
            along: along,
            size: size,
            spans: spans,
            positions: positions,
            rowLength: rowLength,
            focusedPos: focusedIndex.map { positions[$0] },
            focusedSpan: focusedIndex.map { spans[$0] }
                ?? size
        )
    }

    private func frames(
        windows: [WindowID],
        area: CGRect,
        horizontal: Bool,
        offset: CGFloat,
        metrics: Metrics,
        neighbors: ScreenNeighbors
    ) -> [WindowID: CGRect] {
        let along = metrics.along
        let leadingBlocked =
            horizontal ? neighbors.left : true
        let trailingBlocked =
            horizontal ? neighbors.right : neighbors.bottom
        var result: [WindowID: CGRect] = [:]
        for (index, window) in windows.enumerated() {
            let span = metrics.spans[index]
            var lead = offset + metrics.positions[index]
            let peek = min(Self.edgePeek, span)
            lead = min(
                lead,
                trailingBlocked ? along - span : along - peek
            )
            lead = max(
                lead,
                leadingBlocked ? 0 : peek - span
            )
            result[window] =
                horizontal
                ? CGRect(
                    x: area.minX + lead,
                    y: area.minY,
                    width: span,
                    height: area.height
                )
                : CGRect(
                    x: area.minX,
                    y: area.minY + lead,
                    width: area.width,
                    height: span
                )
        }
        return result
    }
}
