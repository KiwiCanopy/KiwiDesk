import ColorSync
import CoreGraphics
import Foundation

/// One display as macOS's Displays arrangement holds it.
struct DisplayReading: Sendable, Equatable {
    let id: DisplayID
    /// Stable across reconnects, where `id` is not (#2756 spike).
    let uuid: String
    /// Global CG points, y growing down.
    let bounds: CGRect
    let isMain: Bool
}

/// macOS's Displays arrangement, read and written through the
/// public CoreGraphics configuration API (#2756): no private
/// symbol, so no fallback is owed. A write lands `.permanently`,
/// which the #2756 spike measured surviving a reconnect and a
/// display sleep, stored by macOS per screen combination. Core
/// reaches both through `TilingEngine`'s arrangement seams, which
/// `makeTestCore` pins.
enum DisplayArrangement {
    /// Every display's reading; nil when one has no UUID, so a
    /// plan never moves screens around one it cannot see.
    static func read(_ displays: [DisplayID]) -> [DisplayReading]? {
        var readings: [DisplayReading] = []
        for id in displays {
            guard let uuid = CGDisplayCreateUUIDFromDisplayID(id.raw)
            else { return nil }
            readings.append(
                DisplayReading(
                    id: id,
                    uuid: CFUUIDCreateString(nil, uuid.takeRetainedValue())
                        as String,
                    bounds: CGDisplayBounds(id.raw),
                    isMain: CGDisplayIsMain(id.raw) != 0
                )
            )
        }
        return readings
    }

    /// The origins a set of moves writes. The main screen stays
    /// at the global origin, so a move of it is written as every
    /// other screen moving the opposite way, which draws the same
    /// arrangement; a screen whose origin does not change is left
    /// out.
    static func targets(
        moves: [DisplayID: CGVector],
        in readings: [DisplayReading]
    ) -> [DisplayID: CGPoint] {
        let anchor =
            readings.first(where: \.isMain).flatMap { moves[$0.id] }
            ?? .zero
        var targets: [DisplayID: CGPoint] = [:]
        for reading in readings {
            let move = moves[reading.id] ?? .zero
            let dx = move.dx - anchor.dx
            let dy = move.dy - anchor.dy
            guard dx != 0 || dy != 0 else { continue }
            targets[reading.id] = CGPoint(
                x: reading.bounds.minX + dx,
                y: reading.bounds.minY + dy
            )
        }
        return targets
    }

    /// Writes the origins in one configuration and keeps them.
    /// Verified by re-reading the bounds, never by the calls'
    /// status; false where the arrangement did not land.
    static func configure(_ targets: [DisplayID: CGPoint]) -> Bool {
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
            let now = CGDisplayBounds(id.raw).origin
            return abs(now.x - origin.x) < 1 && abs(now.y - origin.y) < 1
        }
    }
}
