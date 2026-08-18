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
public struct EffectiveSizeBound: Sendable, Equatable {
    /// One refused axis: the engine asked `asked`, the app
    /// answered `answered`, twice in a row.
    public struct Axis: Sendable, Equatable {
        public var asked: CGFloat
        public var answered: CGFloat

        public init(asked: CGFloat, answered: CGFloat) {
            self.asked = asked
            self.answered = answered
        }
    }

    public var width: Axis?
    public var height: Axis?

    public init(width: Axis? = nil, height: Axis? = nil) {
        self.width = width
        self.height = height
    }

    /// Nothing learned on either axis — the learner drops the
    /// entry rather than keeping an empty one.
    public var isEmpty: Bool { width == nil && height == nil }

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

    /// The width a layout may emit in place of the `span` it is
    /// about to ask: the learned answer iff that ask is the one
    /// the app refused, else nil (a *new* ask must be probed,
    /// not silently swapped — a user who widens a slot past a
    /// stale bound would otherwise never be heard, #677).
    public func consumedWidth(asking span: CGFloat) -> CGFloat? {
        guard let width, Self.matches(width.asked, span)
        else { return nil }
        return width.answered
    }

    /// `consumedWidth`'s vertical twin.
    public func consumedHeight(asking span: CGFloat) -> CGFloat? {
        guard let height, Self.matches(height.asked, span)
        else { return nil }
        return height.answered
    }

    /// The centered residue frame for a slot this bound
    /// refuses (owner ruling on #677): per axis, the answered
    /// span centered in the slot iff the slot's span is the
    /// refused ask; the other axis keeps the slot's extent.
    /// Nil when neither axis consumes — the slot must be asked
    /// as-is. Centered because the residue at the slot origin
    /// reads broken while a symmetric gap reads deliberate;
    /// monocle takes this for its whole slot, scrolling for a
    /// row that cannot re-pack (a single window).
    public func centered(in slot: CGRect) -> CGRect? {
        let width = consumedWidth(asking: slot.width)
        let height = consumedHeight(asking: slot.height)
        guard width != nil || height != nil else { return nil }
        let size = CGSize(
            width: width ?? slot.width,
            height: height ?? slot.height
        )
        return CGRect(
            x: slot.midX - size.width / 2,
            y: slot.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Whether a window sitting at `currentSize` against a
    /// retile's `targetSize` is fully explained by this bound:
    /// per axis, either already within tolerance, or re-asking
    /// the refused ask with the window at the learned answer.
    /// The retile skip consults this so a target the app has
    /// already refused twice is "already there" instead of
    /// re-issued forever (#677).
    public func explains(
        currentSize: CGSize,
        targetSize: CGSize
    ) -> Bool {
        axisExplained(
            bound: width,
            current: currentSize.width,
            target: targetSize.width
        )
            && axisExplained(
                bound: height,
                current: currentSize.height,
                target: targetSize.height
            )
    }

    private func axisExplained(
        bound: Axis?,
        current: CGFloat,
        target: CGFloat
    ) -> Bool {
        if Self.matches(current, target) { return true }
        guard let bound else { return false }
        return Self.matches(target, bound.asked)
            && Self.matches(current, bound.answered)
    }
}

/// The learned answer for an animation whose target re-asks a
/// size the app has refused (#677): per axis, the span the
/// window will actually hold, nil where the tick's size is
/// honest. Bound semantics, so it lives beside
/// `EffectiveSizeBound` — computed by
/// `TilingEngine.animationSizePin(for:)` from the confirmed
/// bound and the in-flight target, consumed by
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
