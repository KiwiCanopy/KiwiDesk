import CoreGraphics
import Foundation

/// Which physical screen holds which number (#3647): Screen k is
/// `fingerprints[k - 1]`. The one crossing between the stored,
/// number-keyed pins and the runtime's fingerprint-keyed ones; a
/// reader takes `KiwiCore.liveScreenOrder`, never an order of its
/// own.
public struct ScreenOrder: Equatable, Sendable {
    public let fingerprints: [String]

    public init(_ fingerprints: [String]) {
        self.fingerprints = fingerprints
    }

    /// The suggested numbering: left to right, ties top to bottom
    /// (AppKit frames, so a higher screen has the larger `maxY`).
    public static func leftToRight(_ displays: [Display]) -> ScreenOrder {
        ScreenOrder(
            displays.sorted {
                if $0.frame.minX != $1.frame.minX {
                    return $0.frame.minX < $1.frame.minX
                }
                return $0.frame.maxY > $1.frame.maxY
            }.map(\.fingerprint)
        )
    }

    /// The runtime key `slot` names, nil for a number past the order.
    public func runtimeKey(of slot: ScreenSlotKey) -> ScreenAreaKey? {
        guard slot.number <= fingerprints.count else { return nil }
        return ScreenAreaKey(
            fingerprint: fingerprints[slot.number - 1],
            areaID: slot.areaID
        )
    }

    /// The number a runtime key's screen holds: the lower one for
    /// twins, which the runtime cannot tell apart. Nil for a screen
    /// outside the order.
    public func slot(of key: ScreenAreaKey) -> ScreenSlotKey? {
        guard let index = fingerprints.firstIndex(of: key.fingerprint)
        else { return nil }
        return ScreenSlotKey(number: index + 1, areaID: key.areaID)
    }

    /// Every number `fingerprint` holds (two for twins).
    public func numbers(of fingerprint: String) -> [Int] {
        fingerprints.indices
            .filter { fingerprints[$0] == fingerprint }
            .map { $0 + 1 }
    }

    /// Stored pins as the runtime keys them; a number past the order
    /// is left out.
    public func runtime(
        _ stored: [SpaceID: ScreenSlotKey]
    ) -> [SpaceID: String] {
        stored.compactMapValues { runtimeKey(of: $0)?.description }
    }

    /// Runtime pins as stored. A pin to a screen outside the order
    /// is dropped; a Space it does not pin keeps a stored number past
    /// the order — a screen left unnumbered, or a hand edit (#3647 ▸
    /// no-fit ruling).
    public func storing(
        runtime: [SpaceID: String],
        over stored: [SpaceID: ScreenSlotKey]
    ) -> [SpaceID: ScreenSlotKey] {
        var result = stored.filter {
            $0.value.number > fingerprints.count
        }
        for (space, pin) in runtime {
            if let slot = slot(of: ScreenAreaKey(parsing: pin)) {
                result[space] = slot
            }
        }
        return result
    }
}
