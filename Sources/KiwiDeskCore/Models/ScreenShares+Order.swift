import Foundation

/// The one crossing between `display_areas` — shares keyed by
/// screen number — and the points-per-fingerprint splits every
/// layout and Settings reader takes (#3647 ▸ lane 3). A screen
/// takes the split of the number `order` gives it, twins the lower
/// number's; a screen no number reaches draws whole.
extension Dictionary where Key == String, Value == ScreenShares {
    /// The shares Screen `number` holds.
    public subscript(number number: Int) -> ScreenShares? {
        get { self[String(number)] }
        set { self[String(number)] = newValue }
    }

    /// The split the screen `fingerprint` takes under `order`, in
    /// its own points; nil where it holds no number or its number
    /// holds no split.
    public func split(
        on fingerprint: String,
        order: ScreenOrder
    ) -> ScreenSplit? {
        guard let number = order.number(of: fingerprint) else {
            return nil
        }
        return self[number: number]?.resolved(on: fingerprint)
    }

    /// Every split of `order`'s screens, keyed by fingerprint.
    public func splits(order: ScreenOrder) -> [String: ScreenSplit] {
        var result: [String: ScreenSplit] = [:]
        for fingerprint in order.fingerprints
        where result[fingerprint] == nil {
            result[fingerprint] = split(on: fingerprint, order: order)
        }
        return result
    }

    /// Every split of `order`'s screens and of each set's own, keyed
    /// by fingerprint: a profile's draft, whose rows name screens no
    /// longer connected. `order` numbers a screen first, then each
    /// set in turn.
    public func splits(
        order: ScreenOrder,
        sets: [MonitorSet]
    ) -> [String: ScreenSplit] {
        var result = splits(order: order)
        for set in sets {
            result.merge(splits(order: set.order)) { kept, _ in kept }
        }
        return result
    }

    /// Stores `split`, laid on the screen `fingerprint`, as the
    /// shares of the number `order` gives it; nil removes them. A
    /// screen holding no number stores nothing; false then.
    @discardableResult
    public mutating func store(
        _ split: ScreenSplit?,
        on fingerprint: String,
        order: ScreenOrder
    ) -> Bool {
        guard let number = order.number(of: fingerprint),
            let size = ScreenShares.size(of: fingerprint)
        else { return false }
        self[number: number] = split.map {
            ScreenShares(
                $0,
                width: size.width,
                height: size.height,
                keeping: self[number: number]
            )
        }
        return true
    }
}
