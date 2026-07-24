import AppKit
import Foundation

/// The coordinated virtual-space-switch transition (#207).
///
/// With `animations.on_space_change` on, a switch used to
/// animate only the INCOMING windows (in from the stash corner)
/// while the outgoing ones vanished instantly — an asymmetric
/// transition that read as unfinished against the symmetric
/// native Spaces swipe. Coordinated, both directions animate
/// CONCURRENTLY in one retile pass: the outgoing windows slide
/// out to their stash corner (`stashInactive(animated: true)`
/// makes today's instant park visible) while the incoming ones
/// slide in from it — the native swipe's own shape (the old
/// desktop slides off as the new one slides in), one animation
/// length total. A sequenced out-then-in variant was tried and
/// rejected on device (owner, 2026-07-24): it doubled the
/// transition time, and its quiet all-parked moment put a
/// spotlight on the corner re-issue's OS clamp correction.
///
/// State (active space, focus, bars, events) commits up front
/// exactly as it always did; only the outgoing frame
/// application gains motion.
///
/// Native macOS Space switches are untouched: AX cannot address
/// an inactive desktop's windows, so that path stays instant in
/// both directions (accepted limitation, #25/#26).
extension KiwiCore {
    /// The retile behind every explicit virtual-space switch —
    /// the single authority for the switch's animation policy.
    /// Instant (both directions) when `on_space_change` is off;
    /// the coordinated concurrent out+in when it is on. Always
    /// forces (§5): switches must push past the "already there"
    /// tolerance, whose state frames lag behind AX echoes
    /// during rapid switching.
    func spaceSwitchRetile() {
        let animated =
            tiler.settings.animations.onSpaceChange
        retile(
            animated: animated,
            force: true,
            stashAnimated: animated
        )
    }
}
