import CoreGraphics
import KiwiDeskCore

/// Desk reading order: left to right, then top to bottom.
///
/// The one statement of that rule for surfaces that list screens
/// the way they sit in front of the user — the Monitors drawer and
/// its chip menus, and the quick menu's per-screen Layout rows.
/// #752 wrote a second copy and got it wrong in both of the ways
/// this comment exists to prevent, so the rule lives here now and
/// the call sites take the key.
///
/// **y is NEGATED, and that is the whole trap.** These origins come
/// from `NSScreen.frame`, whose y grows **up** — so ascending
/// `minY` is bottom-to-top, and a sort that reads naturally lists
/// a laptop *above* the external it sits under.
/// `MonitorArrangement` states the same convention and flips for
/// it when it draws.
///
/// **The identity key is not decoration.** `sorted` is not stable,
/// and x alone ties on any vertically stacked pair — while two
/// mirrored displays tie on x AND y, so without a final key the
/// rows reorder themselves between two opens of the same menu.
/// That is precisely the shuffle `LayoutMenuInfo.orderedScreens`
/// exists to prevent, one cause deeper than the Dictionary
/// ordering it was written for.
///
/// Not to be confused with `PositionalDisplays.ordered`, which
/// answers a different question — it puts the MAIN display first
/// so the built-in layouts can address "second display"
/// positionally, and is not a reading order.
enum DeskOrder {
    /// The sort key for a screen at `origin` identified by `id`.
    static func key(
        origin: CGPoint,
        id: DisplayID
    ) -> (CGFloat, CGFloat, UInt32) {
        (origin.x, -origin.y, id.raw)
    }

    /// Displays in reading order.
    static func reading(_ displays: [Display]) -> [Display] {
        displays.sorted {
            key(origin: $0.frame.origin, id: $0.id)
                < key(origin: $1.frame.origin, id: $1.id)
        }
    }
}
