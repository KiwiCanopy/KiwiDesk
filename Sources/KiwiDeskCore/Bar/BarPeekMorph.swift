import AppKit

/// An anchor the peek grows out of (#2563 ▸ Ruling): the overflow
/// mark's pill becomes its list. The anchor only hides itself while
/// the list stands in its place; it never draws the list.
@MainActor
protocol BarPeekMorphAnchor: NSView {
    /// The area the list may take, in AppKit screen coordinates:
    /// the run's layout bounds.
    var morphRoom: CGRect { get }
    /// The count the pill draws, which stays as the list's header.
    var morphText: String { get }
    /// Takes the anchor out of the pointer's way while its list
    /// shows — the morph hides it — or brings it back as the list
    /// lands, re-reading its hover from the resting `pointer` (AppKit
    /// screen coordinates).
    func setMorphed(_ morphed: Bool, pointer: CGPoint)
}

/// Where the list the pill grows into stands (#2563 ▸ Ruling), in
/// AppKit screen coordinates: its outer edge flush with the pill's,
/// growing inward into the run; on a top or bottom end centred on
/// the pill along it, on a side end hanging from the pill's top so
/// the header and its count sit on the pill — a list centred there
/// would put a row under a double-click's second press (#2063).
/// Clamped to the room. Pure, so its arithmetic is assertable.
enum BarPeekMorph {
    /// The header strip's depth: the pill's, so the count holds
    /// its place.
    static let headerDepth = OverflowMark.depth

    /// The tallest list that fits between the pill's outer edge and
    /// the room's far edge, header included.
    static func maxHeight(
        pill: CGRect,
        edge: AppBarEdge,
        room: CGRect
    ) -> CGFloat {
        switch edge {
        case .top: max(pill.maxY - room.minY, 0)
        case .bottom: max(room.maxY - pill.minY, 0)
        case .left, .right: max(room.height, 0)
        }
    }

    /// The list's frame for a list of `size` grown from `pill` at
    /// a run end facing `edge`.
    static func listFrame(
        size: CGSize,
        pill: CGRect,
        edge: AppBarEdge,
        room: CGRect
    ) -> CGRect {
        var frame = CGRect(origin: .zero, size: size)
        switch edge {
        case .top:
            frame.origin.y = pill.maxY - size.height
        case .bottom:
            frame.origin.y = pill.minY
        case .left:
            frame.origin.x = pill.minX
        case .right:
            frame.origin.x = pill.maxX - size.width
        }
        switch edge {
        case .top, .bottom:
            frame.origin.x = clamped(
                pill.midX - size.width / 2,
                size.width,
                room.minX,
                room.maxX
            )
        case .left, .right:
            frame.origin.y = clamped(
                pill.maxY - size.height,
                size.height,
                room.minY,
                room.maxY
            )
        }
        return CGRect(
            x: frame.minX.rounded(),
            y: frame.minY.rounded(),
            width: frame.width,
            height: frame.height
        )
    }

    /// Whether the header strip runs along the list's top: always,
    /// save on a bottom end, where the pill sits at its foot.
    static func headerAtTop(_ edge: AppBarEdge) -> Bool {
        edge != .bottom
    }

    /// The header strip inside a list of `size` (AppKit, y up).
    static func header(in size: CGSize, edge: AppBarEdge) -> CGRect {
        CGRect(
            x: 0,
            y: headerAtTop(edge) ? size.height - headerDepth : 0,
            width: size.width,
            height: headerDepth
        )
    }

    /// The count's frame in `list`'s own coordinates: across the
    /// pill's x — so clamping the list never moves it — inside the
    /// header strip.
    static func count(
        width: CGFloat,
        pill: CGRect,
        list: CGRect,
        edge: AppBarEdge
    ) -> CGRect {
        let strip = header(in: list.size, edge: edge)
        let x = pill.midX - list.minX - width / 2
        return CGRect(
            x: min(max(x, 0), max(list.width - width, 0)),
            y: strip.minY,
            width: width,
            height: strip.height
        )
    }

    /// Whether a press on the header closes the list: never the
    /// second press of a double-click, nor one within the double-click
    /// interval of the open, so a double-click opens and stays open
    /// (#2063).
    static func headerCloses(
        clickCount: Int,
        sinceOpen: TimeInterval,
        doubleClick: TimeInterval
    ) -> Bool {
        clickCount < 2 && sinceOpen >= doubleClick
    }

    private static func clamped(
        _ origin: CGFloat,
        _ length: CGFloat,
        _ low: CGFloat,
        _ high: CGFloat
    ) -> CGFloat {
        guard high - low >= length else { return origin }
        return min(max(origin, low), high - length)
    }
}

/// What one peek morph moves (#2563, `BarMotion.playMorph`):
/// `stage` clips everything the list draws, glass included, so no
/// glass animates its own frame (#2095); `rows` fades over its
/// second half; the count's two inks cross over the whole motion.
struct BarPeekMorphParts {
    let stage: CALayer
    let rows: CALayer
    let markInk: CALayer
    let listInk: CALayer
}
