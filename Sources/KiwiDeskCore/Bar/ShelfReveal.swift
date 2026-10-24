import CoreGraphics
import Foundation

/// Whether a hiding shelf is shown (#761), and why: the one state
/// a hidden shelf's handle, its hover band and the show/hide
/// action share. Pure, so the timings and the transitions are
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

    /// How long the pointer rests in the band before the shelf
    /// reveals: the band sits on the mark alone, so the wait only
    /// filters a pointer crossing it for a title bar below, as the
    /// drag crossing's and hover peek's dwells do (owner, 2026-10-20).
    static let revealDelay: TimeInterval = 0.15
    /// How long after the pointer leaves the shelf it retracts —
    /// forgiving an overshoot.
    static let retractDelay: TimeInterval = 0.5
    /// The hover band's depth from the shelf's screen side (pt),
    /// whatever the handle draws: the target, not the drawing.
    static let bandDepth: CGFloat = 8
    /// A pointer within this many points of a physical screen
    /// edge the band touches is a push, which reveals at once.
    static let pushReach: CGFloat = 1

    /// The state after the show/hide action: a shown shelf hides,
    /// a hidden one pins, for `duration` seconds where above 0.
    func toggled(now: Date, duration: TimeInterval) -> ShelfReveal {
        if isShown { return .hidden }
        return .pinned(
            until: duration > 0 ? now.addingTimeInterval(duration) : nil
        )
    }

    /// How far the band reaches past the shelf's screen side — up
    /// into a menu bar or a Dock — so a pointer that overshoots
    /// still lands in it (ui-designer, #761).
    static let overshoot: CGFloat = 4
    /// How far around the hidden mark a pointer lights its hover
    /// cue; only the band opens the shelf (owner, #761).
    static let nearReach: CGFloat = 40

    /// The band along `edge` of `strip` — both in one coordinate
    /// space with y growing UP (Cocoa) — that reveals the shelf:
    /// from `outward` past the strip's screen side to `inward`
    /// into it, along the extent of `span` (a rect whose along
    /// axis is the mark's band, `ShelfMarkPlacement`), else
    /// `ShelfMarkPlacement.bandLength` centred on the strip. The
    /// shelf passes the margin and overshoot outward and the
    /// sliver's rest plus the windows' outer gap inward, so the
    /// band ends at the windows.
    static func band(
        of strip: CGRect,
        edge: AppBarEdge,
        along span: CGRect? = nil,
        outward: CGFloat = 0,
        inward: CGFloat = bandDepth
    ) -> CGRect {
        let length = ShelfMarkPlacement.bandLength
        let span =
            span
            ?? CGRect(
                x: strip.midX - length / 2,
                y: strip.midY - length / 2,
                width: length,
                height: length
            )
        switch edge {
        case .top:
            return CGRect(
                x: span.minX,
                y: strip.maxY - inward,
                width: span.width,
                height: inward + outward
            )
        case .bottom:
            return CGRect(
                x: span.minX,
                y: strip.minY - outward,
                width: span.width,
                height: inward + outward
            )
        case .left:
            return CGRect(
                x: strip.minX - outward,
                y: span.minY,
                width: inward + outward,
                height: span.height
            )
        case .right:
            return CGRect(
                x: strip.maxX - inward,
                y: span.minY,
                width: inward + outward,
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
