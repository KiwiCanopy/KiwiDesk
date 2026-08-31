import CoreGraphics
import KiwiDeskCore

/// Positioning logic for "Follows main display" monitor tray (#678 Phase 3).
enum MonitorTray {
    /// Positions and normalizes monitor tray relative to main display card
    /// (`SettingsModel.mainDisplay`).
    static func fold(
        cards: [MonitorArrangement.Drawn],
        main: DisplayID?,
        trayHeight: CGFloat = MonitorArrangement.trayHeight
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
                .map(\.rect),
                height: trayHeight
            )
        }
        let bounds = MonitorArrangement.union(
            cards.map(\.rect) + [tray?.rect].compactMap { $0 }
        )
        let shift = CGPoint(x: -bounds.minX, y: -bounds.minY)
        return MonitorArrangement.Layout(
            displays: cards.map {
                MonitorArrangement.Drawn(
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

    /// Computes pre-normalization tray rect avoiding colliding display cards.
    static func rect(
        anchoredTo anchor: CGRect,
        avoiding others: [CGRect],
        height: CGFloat = MonitorArrangement.trayHeight
    ) -> (rect: CGRect, isAbove: Bool) {
        let width = max(
            anchor.width - inset * 2,
            MonitorArrangement.minimumCard.width
        )
        let x = anchor.midX - width / 2
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
