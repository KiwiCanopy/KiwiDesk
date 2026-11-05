import CoreGraphics

/// The math of a float whose app holds its aspect ratio (#2973).
extension FloatResize {
    /// How an app answered a one-axis size ask, read from where the
    /// window landed.
    public enum AspectAnswer: Equatable {
        /// The pressed axis moved and the other stayed.
        case complied
        case unchanged
        /// Both axes moved and the ratio held. Only a lock does it.
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

    /// Whether two frames stand in one place, within an app's rounding.
    public static func sameOrigin(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= answerTolerance
            && abs(a.minY - b.minY) <= answerTolerance
    }

    /// Reads where a window landed against where it stood, for an ask
    /// on one axis. The other axis moving is the proof of a lock.
    public static func aspectAnswer(
        base: CGSize,
        answered: CGSize,
        horizontal: Bool
    ) -> AspectAnswer {
        let widthMoved = abs(answered.width - base.width) > answerTolerance
        let heightMoved = abs(answered.height - base.height) > answerTolerance
        let pressedMoved = horizontal ? widthMoved : heightMoved
        let otherMoved = horizontal ? heightMoved : widthMoved
        guard otherMoved else {
            return pressedMoved ? .complied : .unchanged
        }
        guard pressedMoved, base.height > 0, answered.height > 0 else {
            return .other
        }
        let drift = abs(
            answered.width / answered.height - base.width / base.height
        )
        return drift <= ratioTolerance ? .fitted : .other
    }

    /// Whether an ask moves the window far enough to read its answer:
    /// a lock carrying it at the base's ratio must move the other axis
    /// past the tolerance, or a small shrink reads as a free window.
    public static func aspectAskIsReadable(
        base: CGSize,
        asked: CGSize,
        horizontal: Bool
    ) -> Bool {
        guard base.width > 0, base.height > 0 else { return false }
        let carried =
            horizontal
            ? abs(asked.width - base.width) * base.height / base.width
            : abs(asked.height - base.height) * base.width / base.height
        return carried > answerTolerance
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
        var refusal: Refusal?
        if delta >= 0 {
            if let bounds {
                let room = min(bounds.width, bounds.height * ratio)
                guard room - frame.width > boundaryTolerance else {
                    return Outcome(frame: frame, refusal: .blocked)
                }
                width = min(width, room)
                if askedWidth - width > boundaryTolerance {
                    refusal = .truncated
                }
            }
            width = max(width, frame.width)
        } else {
            let floor = max(
                shrinkFloor(minSize: min(minSize.width, frame.width)),
                shrinkFloor(minSize: min(minSize.height, frame.height))
                    * ratio
            )
            // At the floor the ratio's height is no ask an app can
            // refuse: mpv fits itself inside it and shrinks (#3018).
            guard frame.width - floor > boundaryTolerance else {
                return Outcome(frame: frame, refusal: nil)
            }
            width = min(max(width, floor), frame.width)
        }
        let across = resized(
            frame,
            horizontal: true,
            delta: width - frame.width,
            minSize: 1,
            bounds: bounds
        )
        let placed = resized(
            across.frame,
            horizontal: false,
            delta: width / ratio - frame.height,
            minSize: 1,
            bounds: bounds
        )
        return Outcome(frame: placed.frame, refusal: refusal)
    }
}
