import CoreGraphics

/// Where a window lands when an explicit float verb floats it,
/// or a move verb files it into a floating Space (#1708)
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
    /// narrower than most apps draw usefully, and at 600 pt a
    /// browser still takes its compact layout (device QA,
    /// 2026-09-26). The short axis takes no floor: two thirds
    /// is already most of a short screen.
    static let longFloor: CGFloat = 800
    /// The long-axis cap, as a multiple of the short-axis span:
    /// a third of an ultrawide is a banner, not a window.
    static let longCap: CGFloat = 1.25

    /// The diagonal step a centred placement takes off a spot
    /// another float already holds (#1708).
    static let cascadeStep: CGFloat = 28

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
        centered(
            defaultSize(in: region, minimum: minimum, maximum: maximum)
                .size,
            in: region
        )
    }

    /// What decided one axis of a default float size short of or
    /// past the asked one (#3554), for the truncation cue.
    public enum SizeLimit: Equatable, Sendable {
        /// A learned app floor raised it.
        case floor
        /// A learned app ceiling capped it.
        case ceiling
        /// The region capped it.
        case region
    }

    /// A default float size and, per axis, the limit that moved it
    /// off the asked size; nil where none did or nothing was asked.
    public struct DefaultSize: Equatable, Sendable {
        public let size: CGSize
        public let width: SizeLimit?
        public let height: SizeLimit?
    }

    /// The default float size in `region` (#3554): `asked` capped to
    /// the region, else the derived size; a learned app `maximum`
    /// caps either and a learned `minimum` outranks both. The one
    /// home of that size and its clamp order, for the placement and
    /// `size_floating`.
    public static func defaultSize(
        in region: CGRect,
        asked: CGSize? = nil,
        minimum: CGSize = .zero,
        maximum: CGSize = CGSize(
            width: CGFloat.infinity,
            height: CGFloat.infinity
        )
    ) -> DefaultSize {
        let derived = derivedSize(in: region)
        func axis(
            _ want: CGFloat?,
            derived: CGFloat,
            span: CGFloat,
            floor: CGFloat,
            ceiling: CGFloat
        ) -> (CGFloat, SizeLimit?) {
            var value = want.map { min($0, span) } ?? derived
            var limit: SizeLimit? =
                want.map { $0 > span ? .region : nil } ?? nil
            if value > ceiling {
                value = ceiling
                limit = want == nil ? nil : .ceiling
            }
            if value < floor {
                value = floor
                limit = want == nil ? nil : .floor
            }
            return (value, limit)
        }
        let width = axis(
            asked?.width,
            derived: derived.width,
            span: region.width,
            floor: minimum.width,
            ceiling: maximum.width
        )
        let height = axis(
            asked?.height,
            derived: derived.height,
            span: region.height,
            floor: minimum.height,
            ceiling: maximum.height
        )
        return DefaultSize(
            size: CGSize(width: width.0, height: height.0),
            width: width.1,
            height: height.1
        )
    }

    /// The size measured on the region's short and long axes.
    static func derivedSize(in region: CGRect) -> CGSize {
        let landscape = region.width >= region.height
        let short = min(region.width, region.height)
        let long = max(region.width, region.height)
        let shortSpan = short * shortShare
        // Never past `long`: the cap is under 5/6 of `short`.
        let longSpan = min(
            max(long * longShare, longFloor),
            shortSpan * longCap
        )
        return landscape
            ? CGSize(width: longSpan, height: shortSpan)
            : CGSize(width: shortSpan, height: longSpan)
    }

    /// `size` centred in `region` and never resized (#3007). An axis
    /// larger than the region pins at its top or left edge, so the
    /// title bar stays reachable and the rest overhangs.
    public static func centered(
        _ size: CGSize,
        in region: CGRect
    ) -> CGRect {
        GeometryUtils.confine(
            CGRect(
                x: region.midX - size.width / 2,
                y: region.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            to: region
        )
    }

    /// `frame` stepped down and right by `cascadeStep` until no
    /// frame in `others` shares its centre, within half a step, or
    /// piles with it by `FloatGather.isPiled` either way (#1708).
    /// Where no such step fits `region` — a float larger than the
    /// walk can leave — the shared centre alone decides, and
    /// `frame` itself where even that finds no step.
    public static func cascaded(
        _ frame: CGRect,
        avoiding others: [CGRect],
        in region: CGRect
    ) -> CGRect {
        let reach = cascadeStep / 2
        func sharesCentre(_ candidate: CGRect) -> Bool {
            others.contains {
                abs($0.midX - candidate.midX) < reach
                    && abs($0.midY - candidate.midY) < reach
            }
        }
        func piles(_ candidate: CGRect) -> Bool {
            others.contains {
                FloatGather.isPiled(candidate, among: [$0])
                    || FloatGather.isPiled($0, among: [candidate])
            }
        }
        return walk(frame, in: region) { sharesCentre($0) || piles($0) }
            ?? walk(frame, in: region, while: sharesCentre)
            ?? frame
    }

    /// The first diagonal step from `frame` that `taken` refuses
    /// not, inside `region`; nil where the walk leaves it first.
    private static func walk(
        _ frame: CGRect,
        in region: CGRect,
        while taken: (CGRect) -> Bool
    ) -> CGRect? {
        var candidate = frame
        while taken(candidate) {
            candidate = candidate.offsetBy(
                dx: cascadeStep,
                dy: cascadeStep
            )
            guard region.contains(candidate) else { return nil }
        }
        return candidate
    }

    /// A remembered float frame placed back in `region` (#1675),
    /// the caller having judged it is on the region's screen: no
    /// larger than the region, no smaller than a learned app
    /// `minimum`, and confined inside it wherever it fits.
    public static func restored(
        _ frame: CGRect,
        in region: CGRect,
        minimum: CGSize = .zero
    ) -> CGRect {
        let size = CGSize(
            width: max(min(frame.width, region.width), minimum.width),
            height: max(
                min(frame.height, region.height),
                minimum.height
            )
        )
        return GeometryUtils.confine(
            CGRect(origin: frame.origin, size: size),
            to: region
        )
    }

    /// Whether a remembered `frame` lies on the screen `region`
    /// sits on (#1675), each judged by the screen it overlaps most
    /// among `screens` — the engine's `allScreenBounds` seam. A
    /// frame or region on no screen is refused, never matched.
    public static func onSameScreen(
        _ frame: CGRect,
        as region: CGRect,
        among screens: [CGRect]
    ) -> Bool {
        func screen(of rect: CGRect) -> CGRect? {
            GeometryUtils.rect(mostlyContaining: rect, among: screens)
        }
        guard let home = screen(of: frame), let target = screen(of: region)
        else { return false }
        return home == target
    }
}
