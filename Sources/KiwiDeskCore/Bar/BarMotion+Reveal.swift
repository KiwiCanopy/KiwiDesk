import AppKit
import QuartzCore

/// `BarMotion`'s reveal half (#761): a hiding shelf slides in from
/// its edge and back out, and fades in place under Reduce Motion.
/// The same one home — `BarMotionSeamTests` censuses this file.
extension BarMotion {
    /// How a reveal or a retract travels.
    enum RevealMotion: Equatable {
        /// The shelf's content slides by this offset from (or to)
        /// its place, in its layer's own coordinates.
        case slide(CGVector, TimeInterval)
        /// It fades in place: Reduce Motion drops the travel,
        /// never the reveal.
        case fade(TimeInterval)
    }

    /// The slide's length (ui-designer, #761): one step longer
    /// than `slide`, so a whole shelf reads as arriving.
    static let revealSlide: TimeInterval = 0.2
    /// The Reduce Motion fade's, as the peek's.
    static let revealFade: TimeInterval = 0.1

    /// The motion for a shelf `depth` deep on `edge`, its content
    /// layer flipped or not.
    static func revealMotion(
        reduceMotion: Bool,
        edge: AppBarEdge,
        depth: CGFloat,
        flipped: Bool
    ) -> RevealMotion {
        guard !reduceMotion else { return .fade(revealFade) }
        let up: CGFloat = flipped ? -1 : 1
        let offset: CGVector
        switch edge {
        case .top: offset = CGVector(dx: 0, dy: depth * up)
        case .bottom: offset = CGVector(dx: 0, dy: -depth * up)
        case .left: offset = CGVector(dx: -depth, dy: 0)
        case .right: offset = CGVector(dx: depth, dy: 0)
        }
        return .slide(offset, revealSlide)
    }

    /// Plays a reveal (`entering`) or a retract on `view`, the
    /// panel's content, and runs `completion` once it lands — on a
    /// timer of its length, as the strip walk's.
    @MainActor
    static func playReveal(
        _ view: NSView,
        edge: AppBarEdge,
        depth: CGFloat,
        entering: Bool,
        completion: @escaping @MainActor () -> Void
    ) {
        view.wantsLayer = true
        guard let layer = view.layer else {
            completion()
            return
        }
        let motion = revealMotion(
            reduceMotion: isReduced,
            edge: edge,
            depth: depth,
            flipped: layer.contentsAreFlipped()
        )
        let span: TimeInterval
        switch motion {
        case .slide(let offset, let duration):
            span = duration
            let away = CATransform3DMakeTranslation(
                offset.dx,
                offset.dy,
                0
            )
            let slide = CABasicAnimation(keyPath: "sublayerTransform")
            slide.fromValue = entering ? away : CATransform3DIdentity
            slide.toValue = entering ? CATransform3DIdentity : away
            slide.duration = duration
            slide.timingFunction = CAMediaTimingFunction(
                name: entering ? .easeOut : .easeIn
            )
            slide.fillMode = .both
            slide.isRemovedOnCompletion = false
            layer.add(slide, forKey: "kiwi.reveal")
        case .fade(let duration):
            span = duration
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = entering ? 0 : 1
            fade.toValue = entering ? 1 : 0
            fade.duration = duration
            fade.fillMode = .both
            fade.isRemovedOnCompletion = false
            layer.add(fade, forKey: "kiwi.reveal")
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(span))
            completion()
        }
    }

    /// Ends a reveal's motion on `view`: the content stands where
    /// it rests.
    @MainActor
    static func endReveal(_ view: NSView) {
        view.layer?.removeAnimation(forKey: "kiwi.reveal")
    }
}
