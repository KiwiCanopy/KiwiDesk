import CoreGraphics
import Foundation

/// Which physical screen holds which number (#3647): Screen k is
/// `fingerprints[k - 1]`, unless k is `unnumbered` — a screen
/// left unnumbered for the session, whose number's pins wait.
/// The one crossing between the stored, number-keyed pins and the
/// runtime's fingerprint-keyed ones; a reader takes
/// `KiwiCore.liveScreenOrder`, never an order of its
/// own, and a number a user types or reads takes
/// `KiwiCore.numberedScreens`.
public struct ScreenOrder: Equatable, Sendable {
    public let fingerprints: [String]
    /// Numbers whose screen holds none this session; never stored,
    /// since a stored set is complete (#3647 ▸ lane 2).
    public let unnumbered: Set<Int>

    public init(_ fingerprints: [String], unnumbered: Set<Int> = []) {
        self.fingerprints = fingerprints
        self.unnumbered = unnumbered
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
    /// runtime cannot tell apart. Nil for a screen outside the order
    /// or holding no number.
    public func slot(of key: ScreenAreaKey) -> ScreenSlotKey? {
        number(of: key.fingerprint).flatMap {
            ScreenSlotKey(number: $0, areaID: key.areaID)
        }
    }

    /// Whether a screen of this order holds `slot`'s number; a
    /// stored number it does not hold waits, and a write keeps it.
    public func holds(_ slot: ScreenSlotKey) -> Bool {
        slot.number <= fingerprints.count
            && !unnumbered.contains(slot.number)
    }

    /// The screen left unnumbered at `number`'s place, nil where
    /// `number` is no hole of this order (#3688).
    public func unnumberedFingerprint(at number: Int) -> String? {
        guard unnumbered.contains(number),
            fingerprints.indices
                .contains(number - 1)
        else { return nil }
        return fingerprints[number - 1]
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
            .filter { !unnumbered.contains($0) }
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
    /// a swap — and `fingerprint` numbered again if it was not. Nil
    /// for a number past the order or a screen outside it.
    public func renumbering(
        _ fingerprint: String,
        to number: Int
    ) -> ScreenOrder? {
        guard number >= 1, number <= fingerprints.count,
            let from = fingerprints.firstIndex(of: fingerprint)
        else { return nil }
        var result = fingerprints
        result.swapAt(from, number - 1)
        // A hole stays with its screen; `fingerprint` is numbered.
        var holes = Set(
            unnumbered.map {
                $0 == from + 1 || $0 == number
                    ? ($0 == from + 1 ? number : from + 1) : $0
            }
        )
        holes.remove(number)
        return ScreenOrder(result, unnumbered: holes)
    }

    /// This order with `fingerprint` left unnumbered: a hole at its
    /// own number, the others keeping theirs. Nil for a screen outside
    /// the order or one with a twin, whose number a pin cannot tell
    /// apart.
    public func unnumbering(_ fingerprint: String) -> ScreenOrder? {
        let numbers = fingerprints.indices
            .filter { fingerprints[$0] == fingerprint }
        guard numbers.count == 1 else { return nil }
        return ScreenOrder(
            fingerprints,
            unnumbered: unnumbered.union([numbers[0] + 1])
        )
    }
}

/// A session renumber with the profile it is for (#3647 ▸ lane 2b).
struct SessionScreenOrder: Equatable {
    var profile: String?
    var order: ScreenOrder
}
