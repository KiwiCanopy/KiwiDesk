/// Batch sizing guarantee for animation transitions (#45, #593,
/// `BatchSizingRoutingTests`).
public enum BatchSizing: Sendable, Equatable {
    /// Pass may instantly size a window or touch one already at final size.
    /// Shrinking axes snap to target on frame 1 to avoid overlap.
    case mayInstantSize
    /// Every window in this pass is smoothly spring-sized from the same clock.
    /// Shrinking axes animate smoothly alongside expanding siblings.
    case allSpringSized
}
