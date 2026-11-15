import ColorSync
import CoreGraphics
import Foundation

/// macOS's Displays arrangement, read and written through the
/// public CoreGraphics configuration API (#2756): no private
/// symbol, so no fallback is owed. A write lands `.permanently`,
/// which the #2756 spike measured surviving a reconnect and a
/// display sleep, stored by macOS per screen combination.
enum DisplayArrangement {
    /// The display's UUID, stable across reconnects where its
    /// `CGDirectDisplayID` is not.
    static func uuid(of display: DisplayID) -> String? {
        guard
            let uuid = CGDisplayCreateUUIDFromDisplayID(display.raw)
        else { return nil }
        return CFUUIDCreateString(nil, uuid.takeRetainedValue())
            as String?
    }

    /// The display's frame in global CG points, y growing down.
    static func bounds(of display: DisplayID) -> CGRect {
        CGDisplayBounds(display.raw)
    }

    static func isMain(_ display: DisplayID) -> Bool {
        CGDisplayIsMain(display.raw) != 0
    }

    /// Moves each display by its delta, in one configuration, and
    /// keeps the moves. The main screen stays at the global origin,
    /// so a move of it is applied as every other screen moving the
    /// opposite way, which draws the same arrangement. Verified by
    /// re-reading the bounds, never by the calls' status; false
    /// where the arrangement did not land.
    @discardableResult
    static func shift(
        _ moves: [DisplayID: CGVector],
        among displays: [DisplayID]
    ) -> Bool {
        let anchor =
            displays.first(where: isMain).flatMap { moves[$0] }
            ?? .zero
        let targets: [(DisplayID, CGPoint)] = displays.compactMap { id in
            let move = moves[id] ?? .zero
            let delta = CGVector(
                dx: move.dx - anchor.dx,
                dy: move.dy - anchor.dy
            )
            guard delta != .zero else { return nil }
            let origin = bounds(of: id).origin
            return (
                id,
                CGPoint(x: origin.x + delta.dx, y: origin.y + delta.dy)
            )
        }
        guard !targets.isEmpty else { return true }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success
        else { return false }
        for (id, origin) in targets {
            let status = CGConfigureDisplayOrigin(
                config,
                id.raw,
                Int32(origin.x.rounded()),
                Int32(origin.y.rounded())
            )
            guard status == .success else {
                CGCancelDisplayConfiguration(config)
                return false
            }
        }
        guard
            CGCompleteDisplayConfiguration(config, .permanently)
                == .success
        else { return false }
        return targets.allSatisfy { id, origin in
            let now = bounds(of: id).origin
            return abs(now.x - origin.x) < 1 && abs(now.y - origin.y) < 1
        }
    }
}
