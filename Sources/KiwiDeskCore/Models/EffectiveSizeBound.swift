import CoreGraphics

/// An app-enforced size bound the engine has learned for one
/// window (#677). AX exposes no minimum/maximum-size attribute
/// (docs/accepted-limitations.md), so the only way to know that
/// a target is unreachable is to have asked and been refused:
/// `asked` is the span the engine set, `answered` the span the
/// app performed instead. Learned per axis, because an app can
/// bound one and comply on the other (System Settings' fixed
/// width, adjustable height), and directionless on purpose —
/// `answered < asked` is a ceiling, `answered > asked` a floor,
/// and both refuse the same way.
///
/// `SizeBoundLearner` owns when one of these is believed; this
/// type owns what a believed one *means*: which ask a layout may
/// swap for the answer (`consumedWidth`/`consumedHeight`), and
/// when a window sitting off its target is explained rather than
/// stranded (`explains`).
///
/// Each axis carries a small SET of refusals keyed by the asked
/// span, not one: different layouts ask the same window
/// different sizes (a scrolling slot vs the monocle area), and a
/// single slot per axis let alternating layouts overwrite each
/// other's entry so the second layout never converged — the
/// monocle dance that never stopped (device QA, 2026-08-18).
///
/// **No ENTRY ever generalizes to a different ask; a
/// CORROBORATED bound does, revocably (#1055 Lane B, owner
/// ruling 2026-08-27).** The distinction carries the whole
/// design. A single entry is grid noise as often as a bound —
/// a terminal answers each ask a few points off, and inferring
/// "ceiling" from one ask would pin every wider ask at a size
/// the app would have accepted. But two asks a real step apart
/// agreeing on one answer is a signature a nearest-cell snap
/// cannot produce below the quantum the distinctness bar
/// protects — `corroborationDistinctness` derives the
/// arithmetic, and the device measurements (Terminal's column
/// and row quanta, System Settings' constant axis-independent
/// answers) are on the issue — while a true fixed bound
/// answers EVERY ask past it with that one span. So
/// `consumedWidth/Height` and `explains` answer an
/// ask BEYOND a corroborated bound with that bound — and the
/// generalization stays falsifiable: a per-ask entry outranks
/// it for any ask it matches, so an app that contradicts the
/// bound at the generalized ask (an aspect-coupled emulator
/// after an other-axis change) corrects itself through the
/// ordinary ladder, and the genuine-resize forget and the
/// compliance sweep clear stale bounds as they always did.
public struct EffectiveSizeBound: Sendable, Equatable {
    /// One refused ask on one axis: the engine asked `asked`,
    /// the app answered `answered`, twice in a row.
    public struct Axis: Sendable, Equatable {
        public var asked: CGFloat
        public var answered: CGFloat

        public init(asked: CGFloat, answered: CGFloat) {
            self.asked = asked
            self.answered = answered
        }
    }

    public var width: [Axis]
    public var height: [Axis]

    public init(width: [Axis] = [], height: [Axis] = []) {
        self.width = width
        self.height = height
    }

    /// Single-entry convenience — most call sites (and every
    /// test fixture) carry one refusal per axis.
    public init(width: Axis? = nil, height: Axis? = nil) {
        self.width = width.map { [$0] } ?? []
        self.height = height.map { [$0] } ?? []
    }

    /// Nothing learned on either axis — the learner drops the
    /// entry rather than keeping an empty one.
    public var isEmpty: Bool {
        width.isEmpty && height.isEmpty
    }

    /// The learned minimum width floor (#933): the largest
    /// answer TWO entries with DISTINCT asks agree on (within
    /// `matchTolerance`), each answering above its ask. This
    /// accessor (and its `maxWidth` mirror) reads ACROSS asks,
    /// so it must not
    /// violate the header's rule that no entry generalizes to a
    /// different ask — and it does not, because it requires the
    /// corroboration a grid-snapping app can never produce: a
    /// terminal answers each ask a few points off (different
    /// answers to different asks), while a true floor answers
    /// every smaller ask with the SAME span. A single
    /// answered-above-asked entry is grid noise as often as a
    /// floor, and believing it pinned shrinks at sizes the app
    /// would have accepted. Nil when uncorroborated (answers at
    /// or below the ask are ceilings and never count).
    public var minWidth: CGFloat? { floor(of: width) }

    /// The learned minimum height floor; see `minWidth`.
    public var minHeight: CGFloat? { floor(of: height) }

    /// The learned maximum width ceiling (#1055) — `minWidth`'s
    /// mirror, under the same corroboration rule and for the
    /// same reason: a grid-snapping app answers each ask a few
    /// points UNDER it too, so a single answered-below-asked
    /// entry is grid noise as often as a ceiling, and believing
    /// it would pin every wider ask at a size the app would
    /// have accepted. A true ceiling answers every larger ask
    /// with the SAME span, which is the corroboration required
    /// here: two entries with DISTINCT asks agreeing on one
    /// answer (within `matchTolerance`), each answering below
    /// its ask. Nil when uncorroborated. Where the floor takes
    /// the largest corroborated answer, the ceiling takes the
    /// smallest — each is the direction in which the bound
    /// binds first.
    public var maxWidth: CGFloat? { ceiling(of: width) }

    /// The learned maximum height ceiling; see `maxWidth`.
    public var maxHeight: CGFloat? { ceiling(of: height) }

    /// Pairwise corroboration, or the FIXED-SPAN lend (#1055
    /// Lane B): a single floor entry whose answer matches a
    /// pairwise-corroborated ceiling is corroborated BY it —
    /// the app answered that one span from both directions,
    /// which is the fixed-width signature (System Settings)
    /// and one no snap grid can produce (its answers track the
    /// ask on both sides). The lend consults only the PAIRED
    /// value of the other direction, never a lent one, so the
    /// two lends cannot bootstrap each other from two single
    /// entries.
    func floor(of entries: [Axis]) -> CGFloat? {
        if let paired = pairedFloor(of: entries) {
            return paired
        }
        guard let ceiling = pairedCeiling(of: entries) else {
            return nil
        }
        return entries.first {
            $0.answered > $0.asked
                && Self.matches($0.answered, ceiling)
        }?.answered
    }

    /// `floor(of:)`'s mirror, lend included; see its doc.
    func ceiling(of entries: [Axis]) -> CGFloat? {
        if let paired = pairedCeiling(of: entries) {
            return paired
        }
        guard let floor = pairedFloor(of: entries) else {
            return nil
        }
        return entries.first {
            $0.answered < $0.asked
                && Self.matches($0.answered, floor)
        }?.answered
    }

    /// How far apart two asks must sit to CORROBORATE a bound
    /// — deliberately wider than `matchTolerance`'s "distinct
    /// entry" quantum (code review, 2026-08-27). The false
    /// pair a nearest-cell snap can produce needs two asks
    /// inside one cell's refusal band, which is (q/2 −
    /// matchTolerance) wide, so a distinctness bar of t
    /// protects every quantum q ≤ 2·(t + matchTolerance).
    /// `matchTolerance` alone (t = 2) protects only q ≤ 8 —
    /// under Terminal's ~7 pt column WIDTH but far under its
    /// row HEIGHT, a line height of ~14–24 pt at ordinary
    /// fonts. 12 protects q ≤ 28, above any ordinary line
    /// height. The default 50 pt resize step and distinct
    /// layout asks corroborate in two observations; a
    /// configured step at or below the bar (`resize_step`
    /// clamps down to 1) or a fine mouse drag corroborates
    /// only once asks drift past it — a few extra silent
    /// presses, not a wrong answer.
    static let corroborationDistinctness: CGFloat = 12

    private func pairedFloor(of entries: [Axis]) -> CGFloat? {
        let floors = entries.filter { $0.answered > $0.asked }
        var best: CGFloat? = nil
        for (index, a) in floors.enumerated() {
            for b in floors.dropFirst(index + 1)
            where abs(a.asked - b.asked)
                > Self.corroborationDistinctness
                && Self.matches(a.answered, b.answered)
            {
                let answer = max(a.answered, b.answered)
                if answer > (best ?? 0) { best = answer }
            }
        }
        return best
    }

    private func pairedCeiling(of entries: [Axis]) -> CGFloat? {
        let ceilings = entries.filter { $0.answered < $0.asked }
        var best: CGFloat? = nil
        for (index, a) in ceilings.enumerated() {
            for b in ceilings.dropFirst(index + 1)
            where abs(a.asked - b.asked)
                > Self.corroborationDistinctness
                && Self.matches(a.answered, b.answered)
            {
                let answer = min(a.answered, b.answered)
                if answer < (best ?? .infinity) { best = answer }
            }
        }
        return best
    }

    /// The quantum for "counts as the same span": AX rounding
    /// and app-side snapping (character grids) wobble an
    /// answered frame by a point or two, so exact comparison
    /// would never match twice. The retile skip check shares
    /// this value (`TilingEngine.retileTolerance` derives from
    /// it) because both answer the same question — does the
    /// frame the app holds count as the frame we named.
    public static let matchTolerance: CGFloat = 2

    static func matches(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) <= matchTolerance
    }

}

/// The learned answer for an animation whose target re-asks a
/// size the app has refused (#677): per axis, the span the
/// window will actually hold, nil where the tick's size is
/// honest. Bound semantics, so it lives beside
/// `EffectiveSizeBound` — computed by
/// `TilingEngine.animationSizePin(for:)` from the in-flight
/// target against the confirmed bound, or provisionally
/// against the first refusal's candidate (rendering
/// self-corrects at settle; geometry stays confirmed-only),
/// consumed by
/// `FollowSource.renderFrame`, whose signature is what drags
/// both overlay managers through any change (borders.md).
public struct SizePin: Sendable, Equatable {
    public var width: CGFloat?
    public var height: CGFloat?

    public init(
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        self.width = width
        self.height = height
    }

    public var isEmpty: Bool {
        width == nil && height == nil
    }
}
