import CoreGraphics

/// Pure geometry of one Space Bar run: where each item sits in the
/// strip and where the trailing front segment starts. Shared by
/// `render()` and the drag-drop hit test (#372) so the highlighted
/// drop target can never disagree with the drawn layout. The run
/// origin is alignment- and front-segment-dependent, so both
/// consumers must derive it from one place. `pad`/`alignment`/
/// `frontExtent` come from the caller (the scalar, already
/// computed on the main actor) so this stays nonisolated and
/// unit-testable.
extension SpaceBarOverlay {
    struct RunMetrics {
        /// Per-item frame in strip-local AX coordinates, in the
        /// same order as the input `lengths`.
        let itemFrames: [CGRect]
        /// Axis coordinate where the front segment begins — the
        /// post-run cursor, one gap past the last item (matching
        /// the pre-extraction loop's trailing `cursor`).
        let frontStart: CGFloat
    }

    nonisolated static func runMetrics(
        lengths: [CGFloat],
        gap: CGFloat,
        frontExtent: CGFloat,
        strip: CGRect,
        horizontal: Bool,
        alignment: SpaceBarStyle.Alignment,
        pad: CGFloat
    ) -> RunMetrics {
        let total =
            lengths.reduce(0, +)
            + gap * CGFloat(max(lengths.count - 1, 0))
            + frontExtent
        var cursor = contentStart(
            total: total,
            axis: horizontal ? strip.width : strip.height,
            alignment: alignment,
            pad: pad
        )
        var frames: [CGRect] = []
        frames.reserveCapacity(lengths.count)
        for length in lengths {
            frames.append(
                horizontal
                    ? CGRect(
                        x: cursor,
                        y: 0,
                        width: length,
                        height: strip.height
                    )
                    : CGRect(
                        x: 0,
                        y: cursor,
                        width: strip.width,
                        height: length
                    )
            )
            cursor += length + gap
        }
        return RunMetrics(itemFrames: frames, frontStart: cursor)
    }
}
