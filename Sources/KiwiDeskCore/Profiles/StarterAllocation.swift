import CoreGraphics
import Foundation

/// Determines initial space counts and layout modes per screen (#678).
/// Budgets total spaces sub-linearly, apportioning by width.
public enum StarterAllocation {
    /// Spaces for 1…4 screens (#3294).
    static let ladder = [3, 5, 5, 5]
    /// Soft cap derived from default shortcut digit capacity.
    public static let softCap = DefaultKeybindings.digitCapacity
    /// Floor outranking `softCap`: at least one space per screen.
    public static let minShare = 1
    /// Upper bound share for a single screen.
    public static let maxShare = 3
    /// Screen count from which the widest screen alone holds two
    /// Spaces and every other screen one (#3294).
    static let wideDeskScreens = 4

    /// Total space budget for `screenCount`: the ladder, then one
    /// per screen plus one, capped at `softCap`; min 1 per screen
    /// always wins.
    public static func budget(screenCount: Int) -> Int {
        let count = max(1, screenCount)
        let budgeted =
            count <= ladder.count
            ? ladder[count - 1]
            : min(softCap, count + 1)
        return max(budgeted, count)
    }

    /// Each screen's share of `budget`: proportional by width
    /// below `wideDeskScreens`; from there one Space a screen and
    /// the remainder on `widest`, by default the widest by points
    /// (#3294).
    static func deskShares(
        widths: [CGFloat],
        budget: Int,
        widest: Int? = nil
    ) -> [Int] {
        guard widths.count >= wideDeskScreens else {
            return shares(widths: widths, budget: budget)
        }
        var share = Array(repeating: minShare, count: widths.count)
        if let widest = widest ?? fillOrder(widths: widths).first {
            share[widest] += min(
                maxShare - minShare,
                max(0, budget - widths.count)
            )
        }
        return share
    }

    /// Apportions budget across screens proportionally by width in points,
    /// clamped to `minShare...maxShare` (code review 2026-08-11).
    public static func shares(
        widths: [CGFloat],
        budget: Int
    ) -> [Int] {
        let count = widths.count
        guard count > 0 else { return [] }
        let total = widths.reduce(0, +)
        let even = Double(budget) / Double(count)
        let raw: [Double] =
            total > 0
            ? widths.map { Double(budget) * Double($0) / Double(total) }
            : Array(repeating: even, count: count)
        var share = raw.map {
            min(maxShare, max(minShare, Int($0.rounded(.down))))
        }
        // Remainder measured against clamped base to prevent bonus inversion.
        let remainder = zip(raw, share).map {
            max(0, $0 - Double($1))
        }
        var deficit = budget - share.reduce(0, +)
        // One unit per pass in ranked order to prevent deficit absorption.
        while deficit > 0 {
            let eligible = rank(remainder, widths, ascending: false)
                .filter { share[$0] < maxShare }
            guard !eligible.isEmpty else { break }
            for index in eligible where deficit > 0 {
                share[index] += 1
                deficit -= 1
            }
        }
        while deficit < 0 {
            let eligible = rank(remainder, widths, ascending: true)
                .filter { share[$0] > minShare }
            guard !eligible.isEmpty else { break }
            for index in eligible where deficit < 0 {
                share[index] -= 1
                deficit += 1
            }
        }
        return share
    }

    /// Layouts per screen in positional order (index 0 = main).
    /// A screen of two or more Spaces opens in `lead(_:of:)`'s
    /// layout before its own list is read (#1018) — the
    /// deliberate exception to the no-repeat rule, appended
    /// without consulting `used` (it still JOINS `used` after, so
    /// no screen draws it twice). A one-Space screen is filled
    /// last, by `singleSpaceLayout(for:placed:)` (#3294).
    public static func modes(sizes: [CGSize]) -> [[LayoutMode]] {
        guard !sizes.isEmpty else { return [] }
        if hasUltrawideCompanion(sizes) {
            return ultrawideModes(sizes: sizes)
        }
        let widths = sizes.map(\.width)
        let share = deskShares(
            widths: widths,
            budget: budget(screenCount: sizes.count)
        )
        let shapes = sizes.map(ScreenClass.of)
        let host = floatingHost(widths: widths, shares: share)
        let order = fillOrder(widths: widths)
        let smallest = smallestScreen(order: order)
        var used: Set<LayoutMode> = []
        var result = [[LayoutMode]](
            repeating: [],
            count: sizes.count
        )
        for index in order where share[index] > 1 {
            var quota = share[index]
            if index == host {
                quota -= 1
                used.insert(.floating)
            }
            var modes: [LayoutMode] = []
            if quota > 0 {
                let first = lead(index, of: smallest)
                modes.append(first)
                used.insert(first)
                quota -= 1
            }
            let list = shapes[index].layouts
            modes += take(
                quota,
                from: list,
                used: &used,
                beside: modes
            )
            if index == host { modes.append(.floating) }
            result[index] = modes
        }
        fillSingleSpaces(
            &result,
            shares: share,
            shapes: shapes,
            order: order
        )
        return result
    }

    /// Opening layout: smallest screen leads Monocle, others Scrolling
    /// (#1018, `StarterLeadTests`).
    static func lead(_ index: Int, of smallest: Int?) -> LayoutMode {
        index == smallest ? .monocle : .scrolling
    }

    /// Screen index that leads Monocle, or nil if single display.
    static func smallestScreen(order: [Int]) -> Int? {
        order.count > 1 ? order.last : nil
    }

    /// Screen receiving the single Floating space (widest with share >= 2).
    static func floatingHost(
        widths: [CGFloat],
        shares: [Int]
    ) -> Int? {
        widths.indices
            .filter { shares[$0] >= 2 }
            .sorted { lhs, rhs in
                widths[lhs] != widths[rhs]
                    ? widths[lhs] > widths[rhs]
                    : lhs < rhs
            }
            .first
    }

    /// Widest screen index first, ties broken by positional order.
    static func fillOrder(widths: [CGFloat]) -> [Int] {
        widths.indices.sorted { lhs, rhs in
            widths[lhs] != widths[rhs]
                ? widths[lhs] > widths[rhs]
                : lhs < rhs
        }
    }

    /// Takes `quota` layouts off the list, never one `used` while
    /// an unused entry remains; past that, an entry this screen
    /// does not hold yet. Under #3294's ladder `quota` is at most
    /// one, the only range where a repeat never sits beside its
    /// twin (`oneScreenAtMostHoldsThree`).
    private static func take(
        _ quota: Int,
        from list: [LayoutMode],
        used: inout Set<LayoutMode>,
        beside: [LayoutMode]
    ) -> [LayoutMode] {
        var picked: [LayoutMode] = []
        for mode in list where picked.count < quota {
            guard !used.contains(mode) else { continue }
            picked.append(mode)
            used.insert(mode)
        }
        while picked.count < quota, let first = list.first {
            let held = Set(picked + beside)
            picked.append(list.first { !held.contains($0) } ?? first)
        }
        return picked
    }

    /// Indices sorted by remainder, then width, then index.
    private static func rank(
        _ remainder: [Double],
        _ widths: [CGFloat],
        ascending: Bool
    ) -> [Int] {
        remainder.indices.sorted { lhs, rhs in
            if remainder[lhs] != remainder[rhs] {
                return ascending
                    ? remainder[lhs] < remainder[rhs]
                    : remainder[lhs] > remainder[rhs]
            }
            if widths[lhs] != widths[rhs] {
                return ascending
                    ? widths[lhs] < widths[rhs]
                    : widths[lhs] > widths[rhs]
            }
            return ascending ? lhs > rhs : lhs < rhs
        }
    }
}
