/// Batch sizing guarantee for animation transitions (#45, #593,
/// `BatchSizingRoutingTests`). A property of the whole PASS, not
/// of the trigger: `allSpringSized` is a promise every window in
/// the batch is spring-sized — opt-in, never inferred, and the
/// guard's `allowed` map is the one list of who may promise it.
/// The failure modes are asymmetric: a wrong `mayInstantSize`
/// merely snaps a shrink; a wrong `allSpringSized` overlaps
/// windows mid-flight.
public enum BatchSizing: Sendable, Equatable {
    /// Pass may instantly size a window or touch one already at final size.
    /// Shrinking axes snap to target on frame 1 to avoid overlap.
    case mayInstantSize
    /// Every window in this pass is smoothly spring-sized from the same clock.
    /// Shrinking axes animate smoothly alongside expanding siblings.
    case allSpringSized
}
