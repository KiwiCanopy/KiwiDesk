/// Whether a window is floating for the purposes of a float
/// safety NET: its own flag, OR a space whose mode places
/// nothing (#500, #1178).
///
/// `FloatingLayout.calculateGeometry` returns no frames, so a
/// `.floating` space's members are unmanaged in exactly the way
/// a flag-floating window is — no layout will ever move them
/// back, which is what makes a net theirs too.
///
/// **A consumer that means effective float asks here: a NET
/// asks it, a VERB keeps the flag.** A net is a
/// correction that places a window nothing else will — the bar
/// clamp, the stash capture, the display-crossing re-anchor. A
/// verb is a user's explicit ask, and whether `resize` should
/// reach a floating-mode member is a product question this type
/// does not answer: `KiwiCore+Resize`, `KiwiCore+ZOrderFloats`,
/// `KiwiCore+SpaceBar` and `KiwiCore+Borders` ask the flag
/// today and are right to until that is ruled. Nothing scans
/// for a bare-flag net, so a new one routes here deliberately.
///
/// Not the negation, either: the drag paths' "is this window a
/// TILED member of this space" chains chain membership and
/// existence beside the mode, and an unknown window is neither
/// floating nor tiled — `!applies` would call it tiled.
public enum EffectiveFloat {
    /// `mode` is the space the window is being judged ON — the
    /// TARGET space for a move, the space a drop LANDED in, the
    /// current one otherwise. Nil (a space the caller cannot
    /// name, or one the window is not a member of) is not
    /// floating: a caller that cannot name the space cannot
    /// claim the exemption.
    public static func applies(
        isFloating: Bool,
        mode: LayoutMode?
    ) -> Bool {
        isFloating || mode == .floating
    }
}
