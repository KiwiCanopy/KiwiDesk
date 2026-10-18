import AppKit
import QuartzCore

/// `BarMotion`'s reveal half (#761): a hiding shelf grows out of
/// its hidden mark and back into it, and fades in place under
/// Reduce Motion.
/// The same one home — `BarMotionSeamTests` censuses this file.
extension BarMotion {
    /// How a reveal or a retract travels.
    enum RevealMotion: Equatable {
        /// The shelf grows out of its hidden mark's plate — the
        /// mark its upper end — to the whole panel, or back into
        /// it: a mask from `from` to `to`, in the content's own
        /// coordinates, its corners rounding off the mark's.
        case grow(from: CGRect, to: CGRect, radius: CGFloat, TimeInterval)
        /// It fades in place: Reduce Motion drops the travel,
        /// never the reveal.
        case fade(TimeInterval)
    }

    /// The grow's length (ui-designer, #761): one step longer than
    /// `slide`, so a whole shelf reads as arriving.
    static let revealSlide: TimeInterval = 0.2
    /// The Reduce Motion fade's, as the peek's.
    static let revealFade: TimeInterval = 0.1

    /// The motion for a shelf whose content spans `bounds`, growing
    /// out of its mark at `origin`.
    static func revealMotion(
        reduceMotion: Bool,
        origin: CGRect,
        bounds: CGRect
    ) -> RevealMotion {
        guard !reduceMotion else { return .fade(revealFade) }
        return .grow(
            from: origin,
            to: bounds,
            radius: min(origin.width, origin.height) / 2,
            revealSlide
        )
    }

    /// Starts a reveal (`entering`) or a retract on `view`, the
    /// panel's content, out of or into its mark at `origin`, and
    /// returns its length; the caller lands it through its own
    /// `afterReveal` seam.
    @MainActor
    @discardableResult
    static func playReveal(
        _ view: NSView,
        origin: CGRect,
        entering: Bool
    ) -> TimeInterval {
        view.wantsLayer = true
        guard let layer = view.layer else { return 0 }
        let motion = revealMotion(
            reduceMotion: isReduced,
            origin: origin,
            bounds: view.bounds
        )
        switch motion {
        case .grow(let from, let to, let radius, let duration):
            let mask = CALayer()
            mask.backgroundColor = NSColor.black.cgColor
            let start = entering ? from : to
            let end = entering ? to : from
            mask.frame = end
            mask.cornerRadius = entering ? 0 : radius
            layer.mask = mask
            let bounds = CABasicAnimation(keyPath: "bounds")
            bounds.fromValue = CGRect(origin: .zero, size: start.size)
            bounds.toValue = CGRect(origin: .zero, size: end.size)
            let position = CABasicAnimation(keyPath: "position")
            position.fromValue = CGPoint(x: start.midX, y: start.midY)
            position.toValue = CGPoint(x: end.midX, y: end.midY)
            let corner = CABasicAnimation(keyPath: "cornerRadius")
            corner.fromValue = entering ? radius : 0
            corner.toValue = entering ? 0 : radius
            let group = CAAnimationGroup()
            group.animations = [bounds, position, corner]
            group.duration = duration
            group.timingFunction = CAMediaTimingFunction(
                name: entering ? .easeOut : .easeIn
            )
            group.fillMode = .both
            group.isRemovedOnCompletion = false
            mask.add(group, forKey: "kiwi.reveal")
            return duration
        case .fade(let duration):
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = entering ? 0 : 1
            fade.toValue = entering ? 1 : 0
            fade.duration = duration
            fade.fillMode = .both
            fade.isRemovedOnCompletion = false
            layer.add(fade, forKey: "kiwi.reveal")
            return duration
        }
    }

    /// Runs `body` once a reveal of `span` seconds has landed — the
    /// overlay's `afterReveal` default; a test hands a queue.
    @MainActor
    static func afterReveal(
        _ span: TimeInterval,
        _ body: @escaping @MainActor () -> Void
    ) {
        Task { @MainActor in
            if span > 0 { try? await Task.sleep(for: .seconds(span)) }
            body()
        }
    }

    /// Ends a reveal's motion on `view`: the content stands where
    /// it rests, unmasked.
    @MainActor
    static func endReveal(_ view: NSView) {
        view.layer?.removeAnimation(forKey: "kiwi.reveal")
        view.layer?.mask = nil
    }

    /// The hidden mark's hover (#761): a short cross-fade into its
    /// grown, rimmed plate, drawn at once under Reduce Motion.
    static let hoverFade: TimeInterval = 0.12

    /// Whether the hover cross-fades: never under Reduce Motion.
    static func crossfades(reduceMotion: Bool) -> Bool { !reduceMotion }

    /// Cross-fades `view`'s next drawing over `hoverFade`; nothing
    /// under Reduce Motion.
    @MainActor
    static func crossfade(_ view: NSView) {
        guard crossfades(reduceMotion: isReduced) else { return }
        view.wantsLayer = true
        let fade = CATransition()
        fade.type = .fade
        fade.duration = hoverFade
        view.layer?.add(fade, forKey: "kiwi.hover")
    }
}
