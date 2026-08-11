import CoreGraphics
import Foundation

/// How many spaces a starter setup creates, and which layout each
/// one gets (#678 Phase 4 pass 11, turn 15b).
///
/// Pure arithmetic over screen SIZES in points — no `Display`, no
/// state — so the whole rule is unit-testable and the seed and the
/// preset face can both call it. `ScreenClass` owns which layouts
/// a shape wants; this owns how many it gets and who places
/// Floating.
///
/// The rule the numbers serve: **budget the total, then give each
/// screen a share it fills from its own list.** Spaces belong to
/// the profile and are merely assigned to a screen, so the count
/// grows with screens sub-linearly — a laptop's 3 plus a 27"'s 5
/// would be eight keys to learn on day one, most of them empty.
/// The cost of a space is a key to bind and a name to recall, not
/// screen area.
public enum StarterAllocation {
    /// Spaces for 1…5 screens. The second and third screen add
    /// two each; every one after that adds one.
    static let ladder = [3, 5, 7, 8, 9]
    /// Past ⌥1–9 and ⌥0 there are no default go-to keys left, so
    /// the total stops growing here. We run out of keys, not
    /// spaces.
    public static let softCap = 10
    /// A screen with no space would have nowhere for a window to
    /// resolve to, so this floor outranks `softCap`.
    public static let minShare = 1
    /// Screens four and five are almost always glanceable — logs,
    /// chat, a stream — and want one space that is always the
    /// same, not a set to switch between.
    public static let maxShare = 3

    /// Total spaces for a screen count. **Min-one-per-screen
    /// always wins**: eleven displays gets eleven spaces, one
    /// apiece, because the cap is on spaces and a screen without
    /// one has nowhere to put a window.
    public static func budget(screenCount: Int) -> Int {
        let count = max(1, screenCount)
        let budgeted =
            count <= ladder.count
            ? ladder[count - 1]
            : min(softCap, ladder[ladder.count - 1] + count - ladder.count)
        return max(budgeted, count)
    }

    /// Each screen's share of the budget, proportional to its
    /// width in points and clamped to `minShare...maxShare`.
    ///
    /// Largest-remainder apportionment, then a repair pass:
    /// clamping can leave the shares off the budget in either
    /// direction, and a share list that does not sum to the
    /// budget is a space the allocator promised and never placed.
    /// The repair can run out of eligible screens (every one at a
    /// clamp), which is why each loop can `break` — the budget
    /// yields to the clamps, never the other way round.
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
        let remainder = raw.map { $0 - $0.rounded(.down) }
        var deficit = budget - share.reduce(0, +)
        while deficit > 0 {
            guard
                let pick = rank(remainder, widths, ascending: false)
                    .first(where: { share[$0] < maxShare })
            else { break }
            share[pick] += 1
            deficit -= 1
        }
        while deficit < 0 {
            guard
                let pick = rank(remainder, widths, ascending: true)
                    .first(where: { share[$0] > minShare })
            else { break }
            share[pick] -= 1
            deficit += 1
        }
        return share
    }

    /// The layouts for every screen, **positional order in,
    /// positional order out** (index 0 = main).
    ///
    /// Two global rules ride on top of the per-screen lists:
    /// exactly one Floating space, on the largest screen that has
    /// room beside it; and no layout twice unless the budget
    /// forces it, which is why the fill runs widest-first — the
    /// screen that benefits most picks first.
    public static func modes(sizes: [CGSize]) -> [[LayoutMode]] {
        guard !sizes.isEmpty else { return [] }
        let widths = sizes.map(\.width)
        let share = shares(
            widths: widths,
            budget: budget(screenCount: sizes.count)
        )
        let shapes = sizes.map(ScreenClass.of)
        let host = floatingHost(widths: widths, shares: share)
        var used: Set<LayoutMode> = []
        var result = [[LayoutMode]](
            repeating: [],
            count: sizes.count
        )
        for index in fillOrder(widths: widths) {
            var quota = share[index]
            if index == host {
                quota -= 1
                used.insert(.floating)
            }
            let list = shapes[index].layouts.filter {
                $0 != .floating
            }
            var modes = take(quota, from: list, used: &used)
            if index == host { modes.append(.floating) }
            result[index] = modes
        }
        return result
    }

    /// The screen that gets the one Floating space: the widest
    /// with a share of at least two.
    ///
    /// The floor is what stops a wide setup's main screen from
    /// being handed Floating and nothing else — at eleven
    /// displays every share is one, every screen is doing a
    /// single job, and there is no room for a space that tiles
    /// nothing. Then there is no Floating space at all, which is
    /// the honest answer rather than a stolen one.
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

    /// Widest first, ties by positional order.
    static func fillOrder(widths: [CGFloat]) -> [Int] {
        widths.indices.sorted { lhs, rhs in
            widths[lhs] != widths[rhs]
                ? widths[lhs] > widths[rhs]
                : lhs < rhs
        }
    }

    /// `quota` layouts off the top of `list`, skipping what
    /// another screen already took. When the list runs dry the
    /// budget has forced a repeat, so it refills from the top of
    /// the same list — still this shape's best-first order.
    private static func take(
        _ quota: Int,
        from list: [LayoutMode],
        used: inout Set<LayoutMode>
    ) -> [LayoutMode] {
        var picked: [LayoutMode] = []
        for mode in list where picked.count < quota {
            guard !used.contains(mode) else { continue }
            picked.append(mode)
            used.insert(mode)
        }
        guard !list.isEmpty else { return picked }
        var cursor = 0
        while picked.count < quota {
            picked.append(list[cursor % list.count])
            cursor += 1
        }
        return picked
    }

    /// Indices ordered by remainder, ties by width then by index,
    /// so the repair pass is deterministic on identical screens.
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
