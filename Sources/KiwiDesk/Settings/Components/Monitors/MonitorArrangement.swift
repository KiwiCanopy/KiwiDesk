import CoreGraphics
import KiwiDeskCore

/// The geometry behind the Monitors picture (#678 Phase 3, turn
/// 13b): real display frames in, drawn rectangles out.
///
/// **Displays are drawn from POINTS** — never pixels, never EDID
/// millimetres (owner ruling 2026-08-04, argued in
/// `docs/design-decisions.md`). Three reasons, and the first is
/// the one that decides it: a display's global POSITION only
/// exists in point space, so sizing from millimetres while
/// positioning from points would tear the picture into gaps and
/// overlaps that exist in neither space, and macOS publishes no
/// physical arrangement to re-derive it from. `Display.frame`
/// comes from `NSScreen.frame`, which is already points, so a
/// Retina display cannot draw 2× an identical non-Retina one:
/// there is no backing-scale term in this file at all, which is
/// the whole of that fix.
///
/// The output is SwiftUI space — y grows DOWN — while the input
/// is AppKit's global space, where y grows UP. The flip is what
/// makes "a laptop below the desk display draws below it" true
/// rather than upside down.
///
/// Pure and nonisolated on purpose: every rule here is arithmetic
/// over values, so `MonitorArrangementTests` asserts the derived
/// rectangles directly rather than scanning for the inputs (the
/// `LayoutSchematicCountTests` shape — a picture that takes the
/// frames and draws a constant satisfies every substring a scan
/// can look for).
enum MonitorArrangement {
    /// One display's drawn rectangle, in canvas coordinates.
    struct Drawn: Equatable, Identifiable {
        let display: Display
        let rect: CGRect
        /// True when the ratio cap shrank this one below true
        /// scale.
        let isClamped: Bool

        var id: DisplayID { display.id }
    }

    /// The whole picture: the cards, the follows-main tray, and
    /// how big the content is (which may exceed the canvas — see
    /// the floor below).
    struct Layout: Equatable {
        var displays: [Drawn] = []
        /// The dashed tray's rectangle, or nil when no display is
        /// main (an empty arrangement).
        var tray: CGRect?
        var trayIsAbove = true
        var contentSize: CGSize = .zero
    }

    // Deliberately NOT a `Layout` field: whether the picture is
    // approximate is asked by the PAGE, which has the displays
    // but not the laid-out picture, and a field beside the static
    // would be a second answer that agrees only by construction —
    // with the guards asserting the field while the screen read
    // the static (guard-prover, 2026-08-04). One answer:
    // `isApproximate(_:)` below.

    /// The largest ratio between the longest sides of any two
    /// drawn displays.
    ///
    /// **The clamp is stated here rather than applied silently**,
    /// because a silent clamp reads as a wrong arrangement. Every
    /// card is a DROP TARGET holding space chips, so an ultrawide
    /// drawn at true scale beside a laptop would shrink the
    /// laptop into a sliver nothing can be dropped onto. Past
    /// this ratio the LARGER display is drawn smaller than true
    /// scale — it only ever shrinks, so the clamp opens gaps and
    /// can never make two rectangles overlap.
    static let maxDrawnRatio: CGFloat = 2.5

    /// How far below true scale the cap must push a display
    /// before the page SAYS the picture is approximate.
    ///
    /// The cap itself has no deadband — it engages at the ratio,
    /// full stop. This is about the sentence: a MacBook beside a
    /// 4K is 3840/1512 ≈ 2.54, a hair over the cap, and drawing
    /// that display 1.6% small is not something a user could see
    /// or would want a permanent caption about. A note that
    /// appears on the commonest two-display desk in the world
    /// teaches people to ignore notes.
    static let perceptibleClamp: CGFloat = 0.9

    /// The smallest a card may be drawn. Derived from the chip
    /// it must hold rather than chosen: card padding either side,
    /// the header line, and exactly one space chip
    /// (`MonitorCardChips`). Below this a card is not a control —
    /// there is nowhere to put the thing you dropped on it.
    ///
    /// It is deliberately the ONE-chip floor and not a
    /// comfortable one: a five-display desk floored at a
    /// chip-shelf size scrolls a picture whose whole job is a
    /// glance, and the chips past the first are reachable through
    /// the card's `+n` either way.
    static let minimumCard = CGSize(
        width: MonitorCardChips.cardPadding * 2
            + MonitorCardChips.minChipWidth,
        height: MonitorCardChips.cardPadding * 2
            + MonitorCardChips.headerHeight
            + MonitorCardChips.chipHeight
    )

    /// Gap between the tray and the display it hangs off.
    static let trayGap: CGFloat = 10
    /// The dashed tray's own height — it holds one chip row, so
    /// it is shorter than a card but not shorter than a chip.
    static let trayHeight: CGFloat = 52

    /// Lays the arrangement out inside `canvas`.
    ///
    /// A display whose frame has a non-positive side is DROPPED
    /// rather than drawn: it can be neither seen nor dropped onto,
    /// and a zero-sized rectangle would take the ratio cap's
    /// divisor to zero. `mainID` names which display the tray
    /// hangs off; a nil or unknown one puts the tray on the first
    /// drawn display, so the tray never silently disappears.
    static func layout(
        displays: [Display],
        mainID: DisplayID?,
        canvas: CGSize
    ) -> Layout {
        let drawable = displays.filter {
            $0.frame.width > 0 && $0.frame.height > 0
        }
        guard !drawable.isEmpty else { return Layout() }

        let capped = capping(drawable)
        let bounds = union(capped.map(\.rect))
        let scale = self.scale(
            for: capped.map(\.rect.size),
            bounds: bounds.size,
            canvas: canvas
        )
        let cards = capped.map { entry in
            Drawn(
                display: entry.display,
                rect: canvasRect(
                    entry.rect,
                    in: bounds,
                    scale: scale
                ),
                isClamped: entry.factor < 1
            )
        }
        return MonitorTray.fold(cards: cards, main: mainID)
    }

    /// Whether the picture is far enough from true scale for the
    /// page to say so.
    ///
    /// A property of the HARDWARE alone — a ratio survives any
    /// uniform scale — so the page can ask without laying the
    /// picture out first, and a guard can assert the threshold
    /// without a canvas.
    static func isApproximate(_ displays: [Display]) -> Bool {
        let drawable = displays.filter {
            $0.frame.width > 0 && $0.frame.height > 0
        }
        return capping(drawable).contains {
            $0.factor < perceptibleClamp
        }
    }

    // MARK: - The three steps

    /// Step 1 — the ratio cap, in POINT space, because a ratio is
    /// scale-free and capping before the scale keeps the scale a
    /// single uniform number.
    ///
    /// The centre is preserved, so a shrunk display stays where
    /// the arrangement puts it: what the cap costs is a gap
    /// against its neighbour, never a move.
    private static func capping(
        _ displays: [Display]
    ) -> [(display: Display, rect: CGRect, factor: CGFloat)] {
        let longest = { (d: Display) in
            max(d.frame.width, d.frame.height)
        }
        // The SMALLEST display sets the ceiling: it is the one
        // whose usability the cap exists to protect.
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

    /// Step 2 and 3 — one uniform scale for the whole picture,
    /// raised until the smallest card is still usable.
    ///
    /// The fit scale is what puts the arrangement inside the
    /// canvas; the floor is what refuses to shrink a drop target
    /// below `minimumCard`. The floor WINS, and the picture then
    /// exceeds the canvas and scrolls — a card too small to drop
    /// a chip onto is a broken control, while a picture wider
    /// than its pane is one the user can still reach every part
    /// of.
    private static func scale(
        for sizes: [CGSize],
        bounds: CGSize,
        canvas: CGSize
    ) -> CGFloat {
        let fit = min(
            canvas.width / max(bounds.width, 1),
            canvas.height / max(bounds.height, 1)
        )
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
