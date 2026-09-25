/// Whether a shelf section follows its active entry into view on
/// a render (#1517): every render follows, except after a MANUAL
/// scroll — a page, a wheel or trackpad scroll, a drag autoscroll
/// — which holds until the active entry changes or the section
/// hides. The one rule both sections hold an instance of.
struct ShelfFollow<Anchor: Equatable> {
    private var followed: Anchor?
    private var hasFollowed = false
    private var held = false

    /// Records the render's active entry and answers whether this
    /// render follows it.
    mutating func follows(_ anchor: Anchor?) -> Bool {
        if !hasFollowed || anchor != followed { held = false }
        hasFollowed = true
        followed = anchor
        return !held
    }

    /// A manual scroll: later renders hold the offset.
    mutating func scrolledByHand() { held = true }

    /// The section hid: its next show follows.
    mutating func reset() { self = Self() }

}
