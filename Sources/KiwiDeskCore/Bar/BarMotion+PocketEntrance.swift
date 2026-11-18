import AppKit
import QuartzCore

/// The One-window pocket's slide out of its edge and back (#2793),
/// which has no handle to rise from: split from
/// `BarMotion+PocketRise` at the §2.1 ceiling.
extension BarMotion {
    /// The One-window pocket's leave out of its edge (#2793), a little
    /// faster than its entrance, the shelf's `revealSlide`.
    static let pocketLeave: TimeInterval = 0.2

    /// Slides the One-window pocket's `view` out of `edge` by
    /// `travel` points, or back into it; returns how long that takes.
    /// Under Reduce Motion it stands or leaves at once.
    @MainActor
    @discardableResult
    static func playPocketEntrance(
        _ view: NSView,
        edge: AppBarEdge,
        travel: CGFloat,
        entering: Bool
    ) -> TimeInterval {
        guard
            let slide = pocketEntrance(
                edge: edge,
                travel: travel,
                // The slide runs in the superview's space, not the
                // view's own.
                flipped: view.superview?.isFlipped ?? false,
                entering: entering,
                reduceMotion: isReduced
            ),
            let layer = view.layer
        else { return 0 }
        layer.add(slide, forKey: "pocketEntrance")
        return slide.duration
    }

    /// The entrance's additive slide, nil under `reduceMotion` or with
    /// no travel: from `travel` points toward `edge` in, or back out,
    /// on the shelf's reveal curve. `flipped` is whether the space the
    /// position moves in, the superview's, runs y down.
    @MainActor
    static func pocketEntrance(
        edge: AppBarEdge,
        travel: CGFloat,
        flipped: Bool,
        entering: Bool,
        reduceMotion: Bool
    ) -> CABasicAnimation? {
        guard !reduceMotion, travel > 0 else { return nil }
        let up: CGFloat = flipped ? -travel : travel
        let away: CGPoint
        switch edge {
        case .top: away = CGPoint(x: 0, y: up)
        case .bottom: away = CGPoint(x: 0, y: -up)
        case .left: away = CGPoint(x: -travel, y: 0)
        case .right: away = CGPoint(x: travel, y: 0)
        }
        let slide = CABasicAnimation(keyPath: "position")
        slide.isAdditive = true
        slide.fromValue = NSValue(point: entering ? away : .zero)
        slide.toValue = NSValue(point: entering ? .zero : away)
        slide.duration = entering ? revealSlide : pocketLeave
        let (a, b, c, d) = revealCurve
        slide.timingFunction =
            entering
            ? CAMediaTimingFunction(controlPoints: a, b, c, d)
            : CAMediaTimingFunction(
                controlPoints: 1 - c,
                1 - d,
                1 - a,
                1 - b
            )
        slide.fillMode = .both
        slide.isRemovedOnCompletion = entering
        return slide
    }
}
