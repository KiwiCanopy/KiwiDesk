import CoreGraphics
import Foundation

/// The Monocle focus-change card flip, decided (#1391).
///
/// Pure: given the commanded focus change and the settings, it
/// answers whether a flip plays and, if so, its axis, its sign
/// and the two plate frames. The overlay renders the answer and
/// `KiwiCore+MonocleFlip` wires it; nothing here touches AppKit.
public struct MonocleFlipPlan: Equatable, Sendable {
    /// Which axis the plate turns about — the FOCUS axis, so the
    /// card turns the way the key pointed: a horizontal Monocle
    /// turns about the vertical axis (left/right, like a page),
    /// a vertical one about the horizontal axis (top/bottom).
    public enum Axis: Equatable, Sendable {
        case vertical
        case horizontal
    }

    public let axis: Axis
    /// `+1` turns forward (next), `-1` back (previous).
    public let sign: Int
    /// The outgoing window's issued frame, AX coordinates.
    public let from: CGRect
    /// The incoming window's issued frame: the outgoing frame's
    /// centre with the target's own size, which is how a
    /// size-bound window is centred in the slot (#677).
    public let to: CGRect
    /// The turn, in seconds.
    public let duration: TimeInterval

    /// Blur fade-in and fade-out around the turn, fixed: the
    /// setting is the turn alone, and the fades are what keep
    /// the swap covered at both ends.
    public static let fadeIn: TimeInterval = 0.12
    public static let fadeOut: TimeInterval = 0.18
    /// How long a burst must be quiet before the blur fades: a
    /// press during a play retargets the card and holds the
    /// blur, which lifts this long after the last press.
    public static let hold: TimeInterval = 0.2

    /// Decides the flip for a commanded focus change from
    /// `current` to `target`.
    ///
    /// - `step`: `+1`/`-1` for a directional step, the pressed
    ///   direction on a wrap included; nil for a non-directional
    ///   target, whose sign is array order (target after current
    ///   = forward).
    /// - `targetSize`: the target's issued size, from the
    ///   layout's frame set — a parked frame's size is the
    ///   window's own.
    /// - Stands down on a disabled setting, Reduce Motion, a
    ///   target that is the current window, or either window not
    ///   a tiled member: a float never flips.
    public static func decide(
        current: WindowID,
        target: WindowID,
        members: [WindowID],
        step: Int?,
        orientation: MonocleParams.Orientation,
        currentFrame: CGRect,
        targetSize: CGSize,
        durationMS: Int,
        enabled: Bool,
        reduceMotion: Bool
    ) -> MonocleFlipPlan? {
        guard enabled, !reduceMotion, current != target,
            let currentIndex = members.firstIndex(of: current),
            let targetIndex = members.firstIndex(of: target)
        else { return nil }
        let sign: Int
        if let step, step != 0 {
            sign = step > 0 ? 1 : -1
        } else {
            sign = targetIndex > currentIndex ? 1 : -1
        }
        let to = CGRect(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.midY - targetSize.height / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        return MonocleFlipPlan(
            axis: orientation == .horizontal ? .vertical : .horizontal,
            sign: sign,
            from: currentFrame,
            to: to,
            duration: TimeInterval(durationMS) / 1000
        )
    }

    /// When, from the start of the play, the focus swaps: once
    /// the blur has covered the surface — the end of the
    /// fade-in, never later, since every millisecond here is
    /// keyboard-focus latency on an all-day verb. The card's
    /// edge-on moment is what the eye follows, not what hides
    /// the swap.
    public var landing: TimeInterval {
        Self.fadeIn
    }

    /// The whole play, fades included.
    public var total: TimeInterval {
        Self.fadeIn + duration + Self.fadeOut
    }

    /// The rect the blur covers: both plate frames, so a larger
    /// outgoing window is blurred to its edge while a smaller
    /// incoming one lands inside it.
    public var cover: CGRect {
        from.union(to)
    }
}
