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
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.axisIsHorizontal

        // A single window fills the whole area (#1389 lets the
        // user keep the slot instead) — unless its app refuses
        // that size (#677): with no neighbors to re-pack against,
        // the answered size is CENTERED (the monocle treatment; a
        // symmetric gap reads deliberate).
        if Self.fillsAlone(windows, context: context),
            let only = windows.first
        {
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
            focus: metrics.subject,
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
    /// (#141, #677). `subject` is the slot the anchor places: the
    /// tiled focus, or — under a fixed anchor while a float holds
    /// focus — the last tiled focus the rest remembers, still in
    /// the row (#1388); `focusedPos` / `focusedSpan` are its.
    struct Metrics {
        let along: CGFloat
        let size: CGFloat
        let spans: [CGFloat]
        let positions: [CGFloat]
        let rowLength: CGFloat
        let subject: WindowID?
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
            gap: gap,
            horizontal: horizontal
        )
        // BSP/Stack/Grid use minWindowSize as a TRIGGER to spill
        // into a pile; scrolling has no pile (its overflow is the
        // scroll itself), so it floors the slot instead.
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
        let subject = Self.subject(of: windows, context: context)
        let focusedIndex = subject.flatMap {
            windows.firstIndex(of: $0)
        }
        return Metrics(
            along: along,
            size: size,
            spans: spans,
            positions: positions,
            rowLength: rowLength,
            subject: subject,
            focusedPos: focusedIndex.map { positions[$0] },
            focusedSpan: focusedIndex.map { spans[$0] }
                ?? size
        )
    }

    /// Whether the one window takes the whole area (#1389) — the
    /// one reading `calculateGeometry` and `viewportRest` share.
    static func fillsAlone(
        _ windows: [WindowID],
        context: LayoutContext
    ) -> Bool {
        windows.count == 1 && context.scrolling.fillWhenAlone
    }

    /// The slot the anchor places: the tiled focus, or under a
    /// fixed anchor the last one the rest remembers while a float
    /// holds focus (#1388, `ScrollingAbsoluteAnchorTests`). A
    /// reorder releases that slot (#1353) and the stand-in with
    /// it until the next tiled focus; `follow` holds its offset
    /// instead (#141) and names none.
    static func subject(
        of windows: [WindowID],
        context: LayoutContext
    ) -> WindowID? {
        if let focused = context.focused, windows.contains(focused) {
            return focused
        }
        guard !context.scrolling.anchor.keepsRowOnScreen,
            let remembered = context.scrollRest?.slot?.window,
            windows.contains(remembered)
        else { return nil }
        return remembered
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
        // A blocked edge — another screen beyond it, or the
        // vertical top macOS walls off itself (#139) — is a hard
        // stop (#878): frames are global and macOS cannot clip
        // another app's window, so an overhang there would render
        // on the neighbor screen — the scrolled-out slot stops
        // flush and stacks behind the viewport (the #150 pile,
        // relocated). An open edge keeps the
        // overhang-with-sliver pin below.
        let leadingBlocked =
            horizontal ? neighbors.left : true
        let trailingBlocked =
            horizontal ? neighbors.right : neighbors.bottom
        var result: [WindowID: CGRect] = [:]
        for (index, window) in windows.enumerated() {
            let span = metrics.spans[index]
            var lead = offset + metrics.positions[index]
            // On an open edge, pin what macOS would refuse anyway
            // (#142): an unreachable target makes every retile
            // re-issue the frame past the ±2 pt tolerance. The
            // peek caps at the slot's own span so a tiny
            // `.fraction` slot pins fully visible; the anchored
            // slot is never touched — `follow`'s visibility clamp
            // and a fixed anchor's own arithmetic both keep its
            // lead inside the axis for a slot the axis can hold.
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
