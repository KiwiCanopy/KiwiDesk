import CoreGraphics
import KiwiDeskCore

/// Where the dashed **Follows main display** tray sits (#678
/// Phase 3, turn 13b).
///
/// The tray is not a fourth card in a row of cards — a space that
/// follows whichever display is main is a statement ABOUT the
/// main display, so it hangs directly off it and moves with the
/// "main" badge. Hanging it off the badge rather than off a fixed
/// corner is the whole reason it is a placement decision at all.
///
/// It goes ABOVE the main display, except where another display
/// already occupies that band — a laptop under a desk display
/// puts the main badge on the lower rectangle, and a tray drawn
/// above it would land on the display above. Then it goes below,
/// and where BOTH bands are taken (a main display in the middle
/// of a vertical stack) it drops clear of the whole picture
/// rather than through a card: a tray drawn over a display is a
/// worse lie than a tray one row further away.
///
/// The picture grows to hold it either way — the tray is part of
/// the content, so putting it above never clips it off the top of
/// the pane.
enum MonitorTray {
    /// Folds the tray into the laid-out cards, normalizing the
    /// whole picture back to a (0, 0) origin.
    ///
    /// `main` names the display the tray hangs off. An id that
    /// matches no card yields NO tray rather than a tray on some
    /// other display: the badge and the tray answer one question,
    /// and a fallback here would be a second derivation of which
    /// display is main — the thing `SettingsModel.mainDisplay`
    /// exists to be the only copy of. In practice the page always
    /// passes a live id, and the nil case is the empty picture.
    static func fold(
        cards: [MonitorArrangement.Drawn],
        main: DisplayID?
    ) -> MonitorArrangement.Layout {
        guard !cards.isEmpty else {
            return MonitorArrangement.Layout()
        }
        let anchor = cards.first { $0.id == main }
        let tray = anchor.map { anchored in
            rect(
                anchoredTo: anchored.rect,
                avoiding: cards.filter { card in
                    card.id != anchored.id
                }
                .map(\.rect)
            )
        }
        let bounds = MonitorArrangement.union(
            cards.map(\.rect) + [tray?.rect].compactMap { $0 }
        )
        // Normalize: the tray above the topmost display puts the
        // picture's origin at a negative y, and a card cannot be
        // drawn at one.
        let shift = CGPoint(x: -bounds.minX, y: -bounds.minY)
        return MonitorArrangement.Layout(
            displays: cards.map {
                MonitorArrangement.Drawn(
                    display: $0.display,
                    rect: $0.rect.offsetBy(
                        dx: shift.x,
                        dy: shift.y
                    ),
                    isClamped: $0.isClamped
                )
            },
            tray: tray?.rect.offsetBy(dx: shift.x, dy: shift.y),
            trayIsAbove: tray?.isAbove ?? true,
            contentSize: bounds.size
        )
    }

    /// The tray's rectangle before normalization: centred on the
    /// display it hangs off, above it where that band is clear,
    /// below it where the band above is taken, and clear of the
    /// whole picture where both are.
    ///
    /// Width follows the anchor so the tray reads as belonging to
    /// it, inset a little so it cannot be mistaken for another
    /// display, with the card minimum as a floor — a tray
    /// narrower than one chip is a drop target nothing fits in.
    static func rect(
        anchoredTo anchor: CGRect,
        avoiding others: [CGRect]
    ) -> (rect: CGRect, isAbove: Bool) {
        let width = max(
            anchor.width - inset * 2,
            MonitorArrangement.minimumCard.width
        )
        let x = anchor.midX - width / 2
        let height = MonitorArrangement.trayHeight
        let gap = MonitorArrangement.trayGap
        func band(_ y: CGFloat) -> CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
        let above = band(anchor.minY - gap - height)
        guard others.contains(where: { $0.intersects(above) })
        else { return (above, true) }
        let below = band(anchor.maxY + gap)
        guard others.contains(where: { $0.intersects(below) })
        else { return (below, false) }
        // Both bands taken: clear the picture entirely.
        let floor = others.map(\.maxY).max() ?? anchor.maxY
        return (band(max(floor, anchor.maxY) + gap), false)
    }

    /// How far the tray is drawn inside the display it hangs off,
    /// so its edges never line up with a card's.
    private static let inset: CGFloat = 12
}
