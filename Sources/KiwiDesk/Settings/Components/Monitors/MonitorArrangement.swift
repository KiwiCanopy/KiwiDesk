import CoreGraphics
import KiwiDeskCore

/// Geometry for Monitors arrangement display (#678).
///
/// Displays are drawn in points from `Display.frame` without backing-scale
/// terms. Flips AppKit y-up coordinates to SwiftUI y-down. Tested by
/// `MonitorArrangementTests` and `LayoutSchematicCountTests`.
enum MonitorArrangement {
    /// Drawn display rectangle in canvas coordinates.
    struct Drawn: Equatable, Identifiable {
        let display: Display
        let rect: CGRect

        var id: DisplayID { display.id }
    }

    /// Full arrangement layout: drawn displays, tray, content size.
    struct Layout: Equatable {
        var displays: [Drawn] = []
        /// Dashed tray rectangle, or nil when no display is main.
        var tray: CGRect?
        var contentSize: CGSize = .zero
    }

    /// Maximum ratio between longest sides of any two drawn displays.
    static let maxDrawnRatio: CGFloat = 2.5

    /// Scale factor threshold below which `isApproximate(_:)` reports true.
    static let perceptibleClamp: CGFloat = 0.9

    /// Minimum card size holding header and at least one chip.
    static let minimumCard = CGSize(
        width: MonitorCardChips.cardPadding * 2
            + MonitorCardChips.minChipWidth,
        height: MonitorCardChips.cardPadding * 2
            + MonitorCardChips.headerHeight
            + MonitorCardChips.stackSpacing
            + MonitorCardChips.chipHeight
    )

    /// Gap between tray and display it hangs off.
    static let trayGap: CGFloat = 10
    /// Dashed tray height.
    static let trayHeight: CGFloat = 52

    /// Lays out arrangement inside `canvas` (`MonitorTray.fold`).
    static func layout(
        displays: [Display],
        mainID: DisplayID?,
        canvas: CGSize,
        hostsChips: Bool = true,
        trayChips: Int = 0
    ) -> Layout {
        let band = trayHeight(chips: trayChips, width: canvas.width)
        let drawable = displays.filter {
            $0.frame.width > 0 && $0.frame.height > 0
        }
        guard !drawable.isEmpty else { return Layout() }

        let capped = capping(drawable)
        let bounds = union(capped.map(\.rect))
        let scale = self.scale(
            for: capped.map(\.rect.size),
            bounds: bounds.size,
            floored: hostsChips,
            canvas: CGSize(
                width: canvas.width,
                height: hostsChips
                    ? max(1, canvas.height - band - trayGap)
                    : canvas.height
            )
        )
        let cards = capped.map { entry in
            Drawn(
                display: entry.display,
                rect: canvasRect(
                    entry.rect,
                    in: bounds,
                    scale: scale
                )
            )
        }
        guard hostsChips else {
            var bare = Layout()
            bare.displays = cards
            return bare
        }
        return MonitorTray.fold(
            cards: cards,
            main: mainID,
            trayHeight: band
        )
    }

    /// Whether scale cap pushed any display below `perceptibleClamp`.
    static func isApproximate(_ displays: [Display]) -> Bool {
        let drawable = displays.filter {
            $0.frame.width > 0 && $0.frame.height > 0
        }
        return capping(drawable).contains {
            $0.factor < perceptibleClamp
        }
    }

    // MARK: - The three steps

    /// Step 1: ratio cap in point space preserving display centers.
    private static func capping(
        _ displays: [Display]
    ) -> [(display: Display, rect: CGRect, factor: CGFloat)] {
        let longest = { (d: Display) in
            max(d.frame.width, d.frame.height)
        }
        let ceiling =
            maxDrawnRatio * (displays.map(longest).min() ?? 0)
        return displays.map { display in
            let factor = min(1, ceiling / longest(display))
            return (
                display,
                scaled(display.frame, by: factor),
                factor
            )
        }
    }

    /// Step 2 & 3: uniform scale fitted to canvas and floored at
    /// `minimumCard`.
    private static func scale(
        for sizes: [CGSize],
        bounds: CGSize,
        floored: Bool,
        canvas: CGSize
    ) -> CGFloat {
        let fit = min(
            canvas.width / max(bounds.width, 1),
            canvas.height / max(bounds.height, 1)
        )
        guard floored else { return fit }
        let floor =
            sizes.map { size in
                max(
                    minimumCard.width / max(size.width, 1),
                    minimumCard.height / max(size.height, 1)
                )
            }
            .max() ?? 0
        return max(fit, floor)
    }

    /// The flip: AppKit's y grows up, the canvas's grows down, so
    /// a rectangle's distance from the arrangement's TOP is what
    /// becomes its y.
    private static func canvasRect(
        _ rect: CGRect,
        in bounds: CGRect,
        scale: CGFloat
    ) -> CGRect {
        CGRect(
            x: (rect.minX - bounds.minX) * scale,
            y: (bounds.maxY - rect.maxY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    // MARK: - Small geometry helpers

    private static func scaled(
        _ rect: CGRect,
        by factor: CGFloat
    ) -> CGRect {
        guard factor < 1 else { return rect }
        let size = CGSize(
            width: rect.width * factor,
            height: rect.height * factor
        )
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func union(_ rects: [CGRect]) -> CGRect {
        guard var result = rects.first else { return .zero }
        for rect in rects.dropFirst() {
            result = result.union(rect)
        }
        return result
    }
}
