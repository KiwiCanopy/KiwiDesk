import CoreGraphics
import KiwiDeskCore

/// Positioning logic for "Follows main screen" tray (#678 Phase 3).
enum ScreenTray {
    /// Positions and normalizes the tray relative to the main
    /// screen card. An id matching no card yields NO tray rather
    /// than a tray on some other screen: a fallback would be a
    /// second derivation of which screen is main —
    /// `SettingsModel.mainDisplay` exists to be the only copy.
    static func fold(
        cards: [ScreenArrangement.Drawn],
        main: DisplayID?,
        trayHeight: CGFloat = ScreenArrangement.trayHeight,
        mainArea: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    ) -> ScreenArrangement.Layout {
        guard !cards.isEmpty else {
            return ScreenArrangement.Layout()
        }
        let anchor = cards.first { $0.id == main }
        let tray = anchor.map { anchored in
            // Under the main screen's first area, where follows-main
            // Spaces land (#3517 ruling 29): the area's span across,
            // the card's own edges for the bands above and below.
            rect(
                anchoredTo: span(of: anchored.rect, area: mainArea),
                avoiding: cards.filter { card in
                    card.id != anchored.id
                }
                .map(\.rect),
                height: trayHeight
            )
        }
        let bounds = ScreenArrangement.union(
            cards.map(\.rect) + [tray?.rect].compactMap { $0 }
        )
        let shift = CGPoint(x: -bounds.minX, y: -bounds.minY)
        return ScreenArrangement.Layout(
            displays: cards.map {
                ScreenArrangement.Drawn(
                    display: $0.display,
                    rect: $0.rect.offsetBy(
                        dx: shift.x,
                        dy: shift.y
                    )
                )
            },
            tray: tray?.rect.offsetBy(dx: shift.x, dy: shift.y),
            contentSize: bounds.size
        )
    }

    /// Computes pre-normalization tray rect avoiding colliding screen cards.
    static func rect(
        anchoredTo anchor: CGRect,
        avoiding others: [CGRect],
        height: CGFloat = ScreenArrangement.trayHeight
    ) -> (rect: CGRect, isAbove: Bool) {
        let width = max(
            anchor.width - inset * 2,
            ScreenArrangement.minimumCard.width
        )
        let x = anchor.midX - width / 2
        let gap = ScreenArrangement.trayGap
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

    /// `card` narrowed to the span `area` (a unit rect) takes
    /// across it, keeping the card's top and bottom.
    static func span(of card: CGRect, area: CGRect) -> CGRect {
        let pane = ScreenArrangement.paneRect(area, in: card.size)
        return CGRect(
            x: card.minX + pane.minX,
            y: card.minY,
            width: pane.width,
            height: card.height
        )
    }

    /// How far the tray is drawn inside the screen it hangs off,
    /// so its edges never line up with a card's.
    private static let inset: CGFloat = 12
}
