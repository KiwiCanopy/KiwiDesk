import CoreGraphics
import Foundation

/// Whether a hiding shelf is shown (#761), and why: the one state
/// a hidden shelf's indicator, its hover band and the show/hide
/// action share. Pure, so the timings and the transitions are
/// assertable; `ShelfRevealer` drives it from the pointer.
enum ShelfReveal: Equatable {
    /// Down to its indicator.
    case hidden
    /// Shown while the pointer holds it.
    case hover
    /// Shown by the action until the next press, or until
    /// `until` where `kiwishelf.reveal_duration` set one.
    case pinned(until: Date?)

    var isShown: Bool { self != .hidden }

    /// How long the pointer rests in the band before the shelf
    /// reveals (ui-designer, from the Dock, the full-screen menu
    /// bar and the hover peek's 0.12 s dwell): long enough that a
    /// pointer passing for a title bar does not pop it.
    static let revealDelay: TimeInterval = 0.35
    /// How long after the pointer leaves the shelf it retracts —
    /// forgiving an overshoot.
    static let retractDelay: TimeInterval = 0.5
    /// The hover band's depth from the shelf's screen side (pt),
    /// whatever the indicator draws: the target, not the drawing.
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

    /// The band along `edge` of `strip` — both in one coordinate
    /// space with y growing UP (Cocoa) — that reveals the shelf.
    static func band(of strip: CGRect, edge: AppBarEdge) -> CGRect {
        let depth = min(
            bandDepth,
            edge.isHorizontal
                ? strip.height : strip.width
        )
        switch edge {
        case .top:
            return CGRect(
                x: strip.minX,
                y: strip.maxY - depth,
                width: strip.width,
                height: depth
            )
        case .bottom:
            return CGRect(
                x: strip.minX,
                y: strip.minY,
                width: strip.width,
                height: depth
            )
        case .left:
            return CGRect(
                x: strip.minX,
                y: strip.minY,
                width: depth,
                height: strip.height
            )
        case .right:
            return CGRect(
                x: strip.maxX - depth,
                y: strip.minY,
                width: depth,
                height: strip.height
            )
        }
    }

    /// Whether `point` pushes against the physical edge of
    /// `screen` the band of `strip` touches — never where a menu
    /// bar or a margin stands between them. Cocoa coordinates.
    static func pushes(
        _ point: CGPoint,
        strip: CGRect,
        edge: AppBarEdge,
        screen: CGRect
    ) -> Bool {
        let band = band(of: strip, edge: edge)
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
