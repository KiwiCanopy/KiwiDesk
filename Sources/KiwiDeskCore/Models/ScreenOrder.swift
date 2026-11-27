import CoreGraphics
import Foundation

/// Which physical screen holds which number (#3647): Screen k is
/// `fingerprints[k - 1]`, and every connected screen holds one
/// (#3647 ▸ always-numbered ruling). The one crossing between the
/// stored, number-keyed pins and the runtime's fingerprint-keyed
/// ones; a reader takes `KiwiCore.liveScreenOrder`, never an order
/// of its own, and a number a user types or reads takes
/// `KiwiCore.numberedScreens`.
public struct ScreenOrder: Equatable, Sendable {
    public let fingerprints: [String]

    public init(_ fingerprints: [String]) {
        self.fingerprints = fingerprints
    }

    /// The suggested numbering: left to right, ties top to bottom
    /// (AppKit frames, so a higher screen has the larger `maxY`).
    public static func leftToRight(_ displays: [Display]) -> ScreenOrder {
        ScreenOrder(displays.sorted(by: precedes).map(\.fingerprint))
    }

    /// Whether `a` comes before `b` left to right, ties top to
    /// bottom: the one geometric order numbers are suggested and
    /// twins told apart in.
    public static func precedes(_ a: Display, _ b: Display) -> Bool {
        if a.frame.minX != b.frame.minX {
            return a.frame.minX < b.frame.minX
        }
        return a.frame.maxY > b.frame.maxY
    }

    /// The runtime key `slot` names, nil for a number past the order.
    public func runtimeKey(of slot: ScreenSlotKey) -> ScreenAreaKey? {
        guard holds(slot) else { return nil }
        return ScreenAreaKey(
            fingerprint: fingerprints[slot.number - 1],
            areaID: slot.areaID
        )
    }

    /// The number a runtime key's screen holds, through
    /// `number(of:)`: the lower numbered one for twins, which the
    /// runtime cannot tell apart. Nil for a screen outside the order.
    public func slot(of key: ScreenAreaKey) -> ScreenSlotKey? {
        number(of: key.fingerprint).flatMap {
            ScreenSlotKey(number: $0, areaID: key.areaID)
        }
    }

    /// Whether a screen of this order holds `slot`'s number; a
    /// stored number it does not hold waits, and a write keeps it.
    public func holds(_ slot: ScreenSlotKey) -> Bool {
        slot.number <= fingerprints.count
    }

    /// The number `fingerprint` answers to: the lower one for twins,
    /// which the runtime cannot tell apart; nil past the order.
    public func number(of fingerprint: String) -> Int? {
        numbers(of: fingerprint).first
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
    /// the order — its screen not connected, or a hand edit (#3647 ▸
    /// no-fit ruling).
    public func storing(
        runtime: [SpaceID: String],
        over stored: [SpaceID: ScreenSlotKey]
    ) -> [SpaceID: ScreenSlotKey] {
        var result = stored.filter { !holds($0.value) }
        for (space, pin) in runtime {
            if let slot = slot(of: ScreenAreaKey(parsing: pin)) {
                result[space] = slot
            }
        }
        return result
    }

    /// This order with Screen `number` given to `fingerprint`, the
    /// screen holding it before taking `fingerprint`'s old number —
    /// a swap. Nil for a number past the order or a screen outside
    /// it.
    public func renumbering(
        _ fingerprint: String,
        to number: Int
    ) -> ScreenOrder? {
        guard number >= 1, number <= fingerprints.count,
            let from = fingerprints.firstIndex(of: fingerprint)
        else { return nil }
        var result = fingerprints
        result.swapAt(from, number - 1)
        return ScreenOrder(result)
    }
}

/// A session renumber with the profile it is for (#3647 ▸ lane 2b).
struct SessionScreenOrder: Equatable {
    var profile: String?
    var order: ScreenOrder
}
