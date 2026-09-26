import CoreGraphics

/// Where a window lands when an explicit float verb floats it
/// (`float_placement`, `docs/design-decisions.md` ▸ the float
/// placement entry). Read only at that moment, never by layout
/// math.
public enum FloatPlacement: String, Sendable, Codable, CaseIterable {
    /// Centred in the float region at the derived size (default).
    case center
    /// The frame it had in the layout, unmoved.
    case keep
}

extension FloatPlacement {
    /// Share of the region's SHORT axis the window spans.
    static let shortShare: CGFloat = 2.0 / 3.0
    /// Share of the region's LONG axis, before the bounds below.
    static let longShare: CGFloat = 1.0 / 3.0
    /// The long-axis floor: a third of a laptop's width is
    /// narrower than most apps draw usefully.
    static let longFloor: CGFloat = 600
    /// The long-axis cap, as a multiple of the short-axis span:
    /// a third of an ultrawide is a banner, not a window.
    static let longCap: CGFloat = 1.25

    /// The centred frame for a window floated in `region` (AX
    /// coordinates). Measured on the region's short and long
    /// axes, so a portrait region gets the landscape one's
    /// shape turned. `minimum` is an app floor learned by the
    /// size-bound ledger and outranks the derived size, as a
    /// learned `maximum` caps it; the result is confined to
    /// `region` wherever it fits.
    public static func centered(
        in region: CGRect,
        minimum: CGSize = .zero,
        maximum: CGSize = CGSize(
            width: CGFloat.infinity,
            height: CGFloat.infinity
        )
    ) -> CGRect {
        let landscape = region.width >= region.height
        let short = min(region.width, region.height)
        let long = max(region.width, region.height)
        let shortSpan = short * shortShare
        // Never past `long`: the cap is under 5/6 of `short`.
        let longSpan = min(
            max(long * longShare, longFloor),
            shortSpan * longCap
        )
        let width = max(
            min(landscape ? longSpan : shortSpan, maximum.width),
            minimum.width
        )
        let height = max(
            min(landscape ? shortSpan : longSpan, maximum.height),
            minimum.height
        )
        let frame = CGRect(
            x: region.midX - width / 2,
            y: region.midY - height / 2,
            width: width,
            height: height
        )
        return GeometryUtils.confine(frame, to: region)
    }
}
