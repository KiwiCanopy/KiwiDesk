import Foundation

/// The fit rule (#3647 ▸ no-fit ruling): a screen takes no number
/// whose split would put an area under the floor there, so a setup
/// is numbered in the first order that fits every screen, ranked
/// against its own; where none fits it keeps its own and the unfit
/// screens draw whole.
extension ScreenOrder {
    /// Whether every numbered screen of this order draws its number's
    /// split under `floors`.
    public func fits(
        _ shares: [String: ScreenShares],
        floors: AreaFloors
    ) -> Bool {
        fingerprints.allSatisfy { fingerprint in
            if case .tooSmall = shares.verdict(
                on: fingerprint,
                order: self,
                floors: floors
            ) {
                return false
            }
            return true
        }
    }

    /// Whether some order of these screens fits every one of them.
    public func anyFits(
        _ shares: [String: ScreenShares],
        floors: AreaFloors
    ) -> Bool {
        candidates.contains { $0.fits(shares, floors: floors) }
    }

    /// This order where it fits; else the fitting order that changes
    /// the fewest screens' numbers, ties to the one that comes first
    /// number by number against this; none fitting, this. An order
    /// with a hole, or past `fitLimit` screens, is kept as it is.
    public func fitting(
        _ shares: [String: ScreenShares],
        floors: AreaFloors
    ) -> ScreenOrder {
        guard !fits(shares, floors: floors) else { return self }
        let fitting = candidates.filter { $0.fits(shares, floors: floors) }
        return fitting.min { a, b in
            let (ma, mb) = (moved(a), moved(b))
            if ma != mb { return ma < mb }
            return places(a).lexicographicallyPrecedes(places(b))
        } ?? self
    }

    /// The most screens the fit search permutes.
    static let fitLimit = 6

    /// Every distinct order of these screens (twins once each way);
    /// this alone for an order with a hole or past the limit.
    private var candidates: [ScreenOrder] {
        guard unnumbered.isEmpty, fingerprints.count <= Self.fitLimit
        else { return [self] }
        return Self.orders(of: fingerprints).map { ScreenOrder($0) }
    }

    private static func orders(of screens: [String]) -> [[String]] {
        guard !screens.isEmpty else { return [[]] }
        var seen = Set<String>()
        var result: [[String]] = []
        for (index, screen) in screens.enumerated()
        where seen.insert(screen).inserted {
            var rest = screens
            rest.remove(at: index)
            result += orders(of: rest).map { [screen] + $0 }
        }
        return result
    }

    /// How many numbers `other` gives another screen than this does.
    private func moved(_ other: ScreenOrder) -> Int {
        zip(fingerprints, other.fingerprints).filter { $0 != $1 }.count
    }

    /// Each of `other`'s screens' place in this order, number by
    /// number.
    private func places(_ other: ScreenOrder) -> [Int] {
        other.fingerprints.map { fingerprints.firstIndex(of: $0) ?? 0 }
    }
}
