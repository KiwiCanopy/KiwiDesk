import CoreGraphics

/// The math of a float whose app holds its aspect ratio (#2973).
extension FloatResize {
    /// How an app answered a size ask, read from where it landed.
    public enum AspectAnswer: Equatable {
        case complied
        case unchanged
        /// Fitted inside the asked box: the axis nobody asked to
        /// change moved too, keeping the ratio. Only a lock does it.
        case fitted
        case other
    }

    /// Slack for an app's whole-point rounding, in points.
    public static let answerTolerance: CGFloat = 2.5
    /// Slack on a ratio read from rounded sizes.
    public static let ratioTolerance: CGFloat = 0.02

    /// A ratio a window's size must leave by this much to replace the
    /// held one. A new video does; an app's rounding must not, or
    /// each press re-bases on the last press's error.
    public static let ratioChange: CGFloat = 0.1

    /// The ratio a press scales by: the held one, until the window
    /// measures clearly different.
    public static func heldRatio(
        _ held: CGFloat,
        measured: CGFloat
    ) -> CGFloat {
        abs(measured - held) > ratioChange ? measured : held
    }

    /// Reads `answered` against the size asked and the size before.
    public static func aspectAnswer(
        base: CGSize,
        asked: CGSize,
        answered: CGSize
    ) -> AspectAnswer {
        func near(_ a: CGSize, _ b: CGSize) -> Bool {
            abs(a.width - b.width) <= answerTolerance
                && abs(a.height - b.height) <= answerTolerance
        }
        if near(answered, asked) { return .complied }
        if near(answered, base) { return .unchanged }
        guard base.height > 0, answered.height > 0 else { return .other }
        let drift = abs(
            answered.width / answered.height - base.width / base.height
        )
        return drift <= ratioTolerance ? .fitted : .other
    }

    /// Resizes `frame` so the pressed axis moves by `delta` and the
    /// other follows at `ratio` (width / height), each axis through
    /// `resized`'s edge split. Both axes stop together at the first
    /// floor or boundary, so the ratio is never traded for room.
    public static func scaled(
        _ frame: CGRect,
        horizontal: Bool,
        delta: CGFloat,
        ratio: CGFloat,
        minSize: CGSize,
        bounds: CGRect?
    ) -> Outcome {
        guard ratio > 0, frame.width > 0, frame.height > 0 else {
            return Outcome(frame: frame, refusal: nil)
        }
        let askedWidth =
            horizontal
            ? frame.width + delta
            : (frame.height + delta) * ratio
        var width = askedWidth
        if delta >= 0 {
            if let bounds {
                width = min(width, bounds.width, bounds.height * ratio)
            }
            width = max(width, frame.width)
        } else {
            let floor = max(
                shrinkFloor(minSize: min(minSize.width, frame.width)),
                shrinkFloor(minSize: min(minSize.height, frame.height))
                    * ratio
            )
            width = min(max(width, floor), frame.width)
        }
        let settled = CGSize(
            width: width.rounded(),
            height: (width / ratio).rounded()
        )
        let across = resized(
            frame,
            horizontal: true,
            delta: settled.width - frame.width,
            minSize: 1,
            bounds: bounds
        )
        let placed = resized(
            across.frame,
            horizontal: false,
            delta: settled.height - frame.height,
            minSize: 1,
            bounds: bounds
        )
        var refusal: Refusal?
        if delta >= 0 {
            let gained = width - frame.width
            if gained <= boundaryTolerance {
                refusal = .blocked
            } else if askedWidth - width > boundaryTolerance {
                refusal = .truncated
            }
        }
        return Outcome(frame: placed.frame, refusal: refusal)
    }
}
