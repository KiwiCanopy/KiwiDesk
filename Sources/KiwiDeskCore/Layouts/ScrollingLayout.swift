import CoreGraphics

/// Niri/PaperWM-style scrolling columns.
///
/// Windows sit in an infinite row (horizontal orientation) or
/// column (vertical) of fixed-size slots. Focus moves scroll the
/// viewport the minimal amount needed to bring the focused slot
/// fully into view (#66) — never more, so up and down are
/// mirror images of each other. The anchor only matters the
/// first time a space scrolls (or after a mode switch), seeding
/// where the initial focused slot sits; from then on the
/// viewport just tracks focus. Slots at the ends snap to the
/// screen edge so no empty margin appears. With the indicator
/// bar enabled its strip is carved out of the usable area
/// first, so windows and bar never overlap.
///
/// Vertical rows overflow only at the bottom: macOS refuses any
/// window position above the top screen border, so a row
/// scrolled past the top pins at the border — its upper strip
/// peeks — instead of tucking above the screen (an accepted
/// OS-blocked limitation, see docs/design-decisions.md). The
/// viewport *offset* stays the ideal, unpinned value, so the
/// up/down scroll math remains symmetric; only the materialized
/// frames pin.
public struct ScrollingLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }

        // The area left for windows after the bar strip.
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.barAxisIsHorizontal

        // A single window always fills the whole window area.
        if windows.count == 1, let only = windows.first {
            return [only: area]
        }

        let metrics = Self.metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        let offset = Self.offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollOffset,
            along: metrics.along,
            size: metrics.size,
            rowLength: metrics.rowLength,
            focusedPos: metrics.focusedPos
        )

        return frames(
            windows: windows,
            area: area,
            horizontal: horizontal,
            offset: offset,
            stride: metrics.stride,
            size: metrics.size
        )
    }

    /// The row geometry shared by `calculateGeometry` and
    /// `viewportOffset`: slot size, stride, total row length, and
    /// the focused slot's position along the scroll axis.
    struct Metrics {
        let along: CGFloat
        let size: CGFloat
        let stride: CGFloat
        let rowLength: CGFloat
        let focusedPos: CGFloat
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
        let size = context.scrolling.slotSize.resolved(
            along: along,
            horizontal: horizontal
        )
        let stride = size + gap
        let count = CGFloat(windows.count)
        let rowLength = count * size + (count - 1) * gap
        let focusedIndex =
            context.focused.flatMap {
                windows.firstIndex(of: $0)
            } ?? 0
        return Metrics(
            along: along,
            size: size,
            stride: stride,
            rowLength: rowLength,
            focusedPos: CGFloat(focusedIndex) * stride
        )
    }

    /// The viewport offset `calculateGeometry` would compute for
    /// `windows`, without materializing frames (#66). Lets the
    /// caller read back the value to persist as the next tile's
    /// `Space.scrollOffset`, so a focus-driven retile can restore
    /// the "previous offset" input without KiwiCore re-deriving
    /// the anchor/clamp math itself. Mirrors the single-window
    /// short-circuit in `calculateGeometry` (offset 0: the lone
    /// window always fills the area).
    static func viewportOffset(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> CGFloat {
        guard windows.count > 1 else { return 0 }
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.barAxisIsHorizontal
        let metrics = metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        return offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollOffset,
            along: metrics.along,
            size: metrics.size,
            rowLength: metrics.rowLength,
            focusedPos: metrics.focusedPos
        )
    }

    /// The viewport offset for a focus at `focusedPos`, given the
    /// offset from the last tile (`previous`).
    ///
    /// Scroll-into-view (#66): if the focused slot is already
    /// fully visible at `previous`, the viewport does not move at
    /// all — panning only ever happens by the minimal amount
    /// needed to reveal the newly focused slot, so stepping focus
    /// up is the exact mirror of stepping it down. `previous ==
    /// nil` (a space that has never scrolled, or just switched
    /// into scrolling mode) falls back to the anchor's preferred
    /// resting position instead, so the very first tile still
    /// respects `scroll.set_anchor`.
    static func offset(
        anchor: ScrollingParams.Anchor,
        previous: CGFloat?,
        along: CGFloat,
        size: CGFloat,
        rowLength: CGFloat,
        focusedPos: CGFloat
    ) -> CGFloat {
        // The range of offsets that keep the focused slot fully
        // inside the viewport: sliding it any further would clip
        // its leading or trailing edge.
        let visibleMin = -focusedPos
        let visibleMax = along - size - focusedPos

        var target: CGFloat
        if let previous {
            target = min(max(previous, visibleMin), visibleMax)
        } else {
            target = anchorOffset(
                anchor: anchor,
                along: along,
                size: size,
                focusedPos: focusedPos
            )
            target = min(max(target, visibleMin), visibleMax)
        }

        // Boundary awareness: never reveal empty margin past the
        // row ends.
        guard rowLength > along else { return 0 }
        return min(max(target, along - rowLength), 0)
    }

    /// The anchor's preferred resting position for a freshly
    /// scrolled focus, before visibility/boundary clamping.
    private static func anchorOffset(
        anchor: ScrollingParams.Anchor,
        along: CGFloat,
        size: CGFloat,
        focusedPos: CGFloat
    ) -> CGFloat {
        switch anchor {
        case .center:
            return (along - size) / 2 - focusedPos
        case .left:
            return -focusedPos
        case .right:
            return along - size - focusedPos
        }
    }

    private func frames(
        windows: [WindowID],
        area: CGRect,
        horizontal: Bool,
        offset: CGFloat,
        stride: CGFloat,
        size: CGFloat
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        for (index, window) in windows.enumerated() {
            var lead = offset + CGFloat(index) * stride
            // macOS silently rejects frames above the top
            // screen border (WindowServer clamp; the SIP
            // guardrail rules out private workarounds). Pin
            // vertical up-overflow rows at the edge so targets
            // stay achievable — otherwise every retile re-issues
            // an impossible frame that the ±2pt tolerance can
            // never absorb. The focused row is unaffected: the
            // offset clamp keeps its lead in view (>= 0).
            if !horizontal { lead = max(lead, 0) }
            result[window] =
                horizontal
                ? CGRect(
                    x: area.minX + lead,
                    y: area.minY,
                    width: size,
                    height: area.height
                )
                : CGRect(
                    x: area.minX,
                    y: area.minY + lead,
                    width: area.width,
                    height: size
                )
        }
        return result
    }
}
