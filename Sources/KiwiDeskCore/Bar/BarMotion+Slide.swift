import QuartzCore

/// The Space-switch plate slide's motion (#1956). Under Reduce
/// Motion the slide never plays — `KiwiCore.spaceSlideStandsDown`
/// takes the instant switch — so each reduced shape here is the
/// zero-travel step `flipFade` keeps as a net.
extension BarMotion {
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
