import CoreGraphics
import Foundation

/// Whether a hiding shelf is shown (#761), and why: the one state
/// a hidden shelf's handle, its approach and the show/hide action
/// share. Pure, so the timings and the transitions are
/// assertable; `ShelfRevealer` drives it from the pointer.
enum ShelfReveal: Equatable {
    /// Down to its handle.
    case hidden
    /// Shown while the pointer holds it.
    case hover
    /// Shown by the action until the next press, or until
    /// `until` where `kiwishelf.reveal_timeout` set one.
    case pinned(until: Date?)

    var isShown: Bool { self != .hidden }

    /// How long the pointer rests on the thickened handle before
    /// the bar opens (owner, 2026-10-20; #3349 rule 3).
    static let revealDelay: TimeInterval = 0.15
    /// How long after the pointer leaves the shelf it retracts —
    /// forgiving an overshoot.
    static let retractDelay: TimeInterval = 0.5
    /// How long the pointer stays in the approach before the
    /// handle thickens and its contents peek through (#3349).
    static let approachDelay: TimeInterval = 0.15
    /// How long the pointer lingers in the approach, counted from
    /// its entry, before the bar opens off the handle — the same
    /// on every edge (#3349 rule 3; set with the owner on the
    /// device).
    static let dwellDelay: TimeInterval = 0.4
    /// How far in from the edge the approach reaches (pt).
    static let approachReach: CGFloat = 24
    /// How far past each end of the bar's run the approach reaches
    /// along the edge (pt).
    static let alongReach: CGFloat = 12
    /// A pointer within this many points of a physical screen
    /// edge is on its outermost row: a push.
    static let pushReach: CGFloat = 1
    /// How far the approach reaches outward past the screen side
    /// of the shelf's area, past its margin — so a pointer that
    /// overshoots into a menu bar or a Dock stays in it
    /// (ui-designer, #761).
    static let overshoot: CGFloat = 4

    /// The state after the show/hide action: a shown shelf hides,
    /// a hidden one pins, for `duration` seconds where above 0.
    func toggled(now: Date, duration: TimeInterval) -> ShelfReveal {
        if isShown { return .hidden }
        return .pinned(
            until: duration > 0 ? now.addingTimeInterval(duration) : nil
        )
    }

    /// The approach along `edge` (#3349), Cocoa: the bar's `run`
    /// widened by `alongReach` each end, across from `outward`
    /// past `side` — the screen side of the shelf's area, a
    /// coordinate on the edge's axis — to `inward` in.
    static func approach(
        along run: CGRect,
        edge: AppBarEdge,
        side: CGFloat,
        outward: CGFloat,
        inward reach: CGFloat = approachReach
    ) -> CGRect {
        switch edge {
        case .top:
            return CGRect(
                x: run.minX - alongReach,
                y: side - reach,
                width: run.width + 2 * alongReach,
                height: reach + outward
            )
        case .bottom:
            return CGRect(
                x: run.minX - alongReach,
                y: side - outward,
                width: run.width + 2 * alongReach,
                height: reach + outward
            )
        case .left:
            return CGRect(
                x: side - outward,
                y: run.minY - alongReach,
                width: reach + outward,
                height: run.height + 2 * alongReach
            )
        case .right:
            return CGRect(
                x: side - reach,
                y: run.minY - alongReach,
                width: reach + outward,
                height: run.height + 2 * alongReach
            )
        }
    }

    /// The outermost row of `screen` along `edge`, across the
    /// extent of `span` — where a push lands, Cocoa. `CGRect`
    /// excludes its max edge, so the row reaches one point past
    /// the screen to keep the last pixel inside.
    static func edgeRow(
        along span: CGRect,
        edge: AppBarEdge,
        screen: CGRect
    ) -> CGRect {
        let row = pushReach
        switch edge {
        case .top:
            return CGRect(
                x: span.minX,
                y: screen.maxY - row,
                width: span.width,
                height: 2 * row
            )
        case .bottom:
            return CGRect(
                x: span.minX,
                y: screen.minY - row,
                width: span.width,
                height: 2 * row
            )
        case .left:
            return CGRect(
                x: screen.minX - row,
                y: span.minY,
                width: 2 * row,
                height: span.height
            )
        case .right:
            return CGRect(
                x: screen.maxX - row,
                y: span.minY,
                width: 2 * row,
                height: span.height
            )
        }
    }

    /// Whether `point` pushes against the physical edge of
    /// `screen` inside `band` — the mark's own, never the whole
    /// edge or a corner — and never where a menu bar or a margin
    /// stands between `strip` and that edge. Cocoa coordinates.
    static func pushes(
        _ point: CGPoint,
        band: CGRect,
        strip: CGRect,
        edge: AppBarEdge,
        screen: CGRect
    ) -> Bool {
        guard
            band.insetBy(dx: -pushReach, dy: -pushReach)
                .contains(point)
        else { return false }
        switch edge {
        case .top:
            return screen.maxY - strip.maxY <= pushReach
                && point.y >= screen.maxY - pushReach
        case .bottom:
            return strip.minY - screen.minY <= pushReach
                && point.y <= screen.minY + pushReach
        case .left:
            return strip.minX - screen.minX <= pushReach
                && point.x <= screen.minX + pushReach
        case .right:
            return screen.maxX - strip.maxX <= pushReach
                && point.x >= screen.maxX - pushReach
        }
    }
}
