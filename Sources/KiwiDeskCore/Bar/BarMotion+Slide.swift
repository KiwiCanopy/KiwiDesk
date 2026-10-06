import QuartzCore

/// The Space-switch plate slide's motion (#1956). Under Reduce
/// Motion the slide never plays — `KiwiCore.spaceSlideStandsDown`
/// takes the instant switch — so each reduced shape here is the
/// zero-travel step `flipFade` keeps as a net.
extension BarMotion {
    /// A layer `opacity` fade from `from` to `to` across
    /// `duration`, starting at render-server time `begin` — taken
    /// from the press rather than from when the main thread gets
    /// here, since a switch's own turn runs 100 ms and more.
    static func slideFade(
        from: Float,
        to: Float,
        begin: CFTimeInterval,
        duration: CFTimeInterval,
        reduceMotion: Bool
    ) -> CAAnimation {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = reduceMotion ? to : from
        fade.toValue = to
        fade.beginTime = begin
        fade.duration = max(duration, 0.001)
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        // Forwards only, as `flipFade`: a later fade on the key
        // must not be overridden from the start.
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        return fade
    }

    /// The strip's spring along `keyPath` (a translation), the
    /// motion `strip` models; it holds `strip.from` until
    /// `strip.begin`.
    static func slideSpring(
        keyPath: String,
        strip: SpaceSlideStrip,
        reduceMotion: Bool
    ) -> CAAnimation {
        let spring = CASpringAnimation(keyPath: keyPath)
        spring.mass = 1
        spring.stiffness = strip.stiffness
        spring.damping = strip.damping
        spring.fromValue = reduceMotion ? strip.to : strip.from
        spring.toValue = strip.to
        spring.initialVelocity =
            reduceMotion ? 0 : strip.normalizedVelocity
        spring.beginTime = strip.begin
        spring.duration = spring.settlingDuration
        spring.fillMode = .both
        spring.isRemovedOnCompletion = false
        return spring
    }
}
