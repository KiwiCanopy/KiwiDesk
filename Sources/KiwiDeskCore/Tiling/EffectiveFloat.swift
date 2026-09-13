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
/// asks it, and a VERB asks it once ruled.** A net is a
/// correction that places a window nothing else will — the bar
/// clamp, the stash capture, the display-crossing re-anchor. A
/// verb is a user's explicit ask, and whether one should reach
/// a floating-mode member is a product question per verb, which
/// this type does not answer.
///
/// This docstring is the one roster of which verbs — and which
/// readers that are no verb, a ring or a raise — are ruled.
/// `resize` is ruled onto the predicate (#1184,
/// `FloatingResizeCommandTests`), standing down for a
/// native-fullscreen window (#670) on both arms — one arm alone
/// would put the divergence the crossing removed back at that
/// one window — and it stands the VERB down, not the float
/// ROUTE, which would drop the press into the layout and let a
/// window nothing places move its neighbours. #1286 swept the
/// flag's readers and ruled two more the same way: the unfocused
/// focus ring stands down for an effective float on the space it
/// renders on (`KiwiCore+Borders`, `FloatingModeRingTests`), and
/// the float-tier raise stands down after a focus that lands on
/// one and takes no floating-mode member as its FLOOR
/// (`KiwiCore+ZOrderFloats.raiseFloatsAbove`, `floatRaiseFloor`,
/// `FloatingModeRaiseTests`) while its TARGETS stay the flag's,
/// there being no tiled plane in a floating-mode space to lift
/// over. Ruled to STAY on the flag: the Space Bar float badge and
/// the group-breaking beside it (`KiwiCore+SpaceBarItems`), which
/// mark the exception to a space's layout and in a floating-mode
/// space have none to mark (owner ruling 2026-09-13,
/// `SpaceBarBadgeTests`). Every other reader is the flag's own
/// identity, a net already routed here, or a "tiled member"
/// question — the negation below — and
/// `FloatFlagReaderCensusTests` holds that census per file, so a
/// new `.isFloating` read reds until it is classified there; the
/// argument per reader is the comment on #1286. A verb or reader
/// ruled later states its own stand-down — always the verb's,
/// never the route's.
///
/// Not the negation, either: the drag paths' "is this window a
/// TILED member of this space" chains chain membership and
/// existence beside the mode, and an unknown window is neither
/// floating nor tiled — `!applies` would call it tiled.
public enum EffectiveFloat {
    /// `mode` is the space the window is being judged ON — the
    /// TARGET space for a move, the space a drop LANDED in, the
    /// current one otherwise. Nil (a space the caller cannot
    /// name) is not floating: a caller that cannot name the
    /// space cannot claim the exemption. A TRAVELER — a tiled
    /// sticky rendering on a space it is no member of — takes
    /// the space it RENDERS on where the consumer plays out
    /// there (the re-home, #1217; the ring, #1286) and nil where
    /// the consumer's strips or slots are a MEMBER's (the drop
    /// clamp, the raise): `KiwiCore.isEffectiveFloatOnActiveSpace`
    /// is the one door for the latter.
    public static func applies(
        isFloating: Bool,
        mode: LayoutMode?
    ) -> Bool {
        isFloating || mode == .floating
    }
}
