/// What a caller can promise about **how every window in one
/// animation batch gets its size** — the single input that decides
/// whether a shrinking axis may follow the spring (#593).
///
/// Deliberately a property of the batch, not a name for the
/// trigger. The distinction is the whole design, so it is worth
/// the paragraph:
///
/// The hazard the first-frame shrink snap exists for (#45) is
/// **not** "a window shrank slowly". It is an *instantly-sized*
/// window sharing the screen with a smoothly-sized one.
/// `AnimationEngine.animate(isNewWindow: true)` pre-sets a
/// newcomer's target size at its current position, so a window
/// that just opened is already full size on frame 1; a sibling
/// vacating its room gradually then sits underneath it for the
/// length of the flight. Where nothing is instantly sized, every
/// window runs the same spring on the same clock for the same
/// duration, so a shared edge moves in lockstep and there is no
/// gap to expose.
///
/// So the question a caller answers is *does this pass place any
/// window at its final size in one frame* — not "is this a
/// resize", not "is this axis shrinking", not "did membership
/// change". Naming the cases after triggers would invite exactly
/// the reasoning that gets this wrong, and the trigger vocabulary
/// is already spoken for several times over: `on_relayout`,
/// `on_window_resize`, `on_window_swap` and `retile(animated:)`
/// all slice retiles by trigger, with different extents. This
/// type slices them by a different question and keeps out of that
/// namespace.
///
/// **`.mayInstantSize` is the default and `.allSpringSized` is
/// opt-in, never inferred.** The failure modes are not
/// symmetric: forgetting to promise costs a snap, which is
/// cosmetic and exactly the pre-#593 behavior, while promising
/// falsely costs a visible overlap on every window open.
/// `BatchSizingRoutingTests` pins which call sites may promise,
/// and **its `allowed` map is that list** — this comment
/// deliberately does not keep a second copy.
public enum BatchSizing: Sendable, Equatable {
    /// This pass may place a window at its final size in a single
    /// frame — a newcomer pre-sized by `isNewWindow`, a float
    /// restored by `setFrame`, an un-animated placement — **or it
    /// touches a window that was already at its final size when
    /// the pass began**: one the pointer just placed, one the
    /// retile tolerance skips. Either way something on screen is
    /// at its final size while a sibling is still travelling, so a
    /// shrinking axis snaps to its target on frame 1 and any room
    /// it is yielding clears before that sibling is overlapped.
    ///
    /// The default, and true at the several hundred call sites
    /// that never mention this type. Note the *may*: it is a
    /// refusal to promise, not a claim that something is being
    /// instantly sized.
    case mayInstantSize
    /// Every window this pass touches is spring-sized, from the
    /// same clock, for the same duration. A shrinking axis then
    /// follows the spring under the same throttle the growing one
    /// uses, so a shared edge slides instead of jumping.
    ///
    /// Promising this of a pass that opens, closes or re-slots a
    /// window reintroduces #45.
    case allSpringSized
}
