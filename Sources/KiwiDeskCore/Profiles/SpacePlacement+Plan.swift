import Foundation

/// The positional plan, `SpacePlacement`'s third rung (#53): where a
/// Space no pin and no Main role places lands, by its number.
extension SpacePlacement {
    /// The FROZEN plan the pre-#3294 Standards drew — Spaces 1–4 on
    /// the main screen; 5–8 on a second; with three, 5–7 and 8–10;
    /// each further screen the next number — kept apart from the
    /// preset family, so a family change moves no such Space on
    /// upgrade (#3294; profiles.md). It deliberately does not share
    /// `ProfileComposition.compose`'s extra-screen loop, which
    /// follows the family. The display resolve and the Settings
    /// pictures read this one plan.
    public static func numberedPlan(
        displays: [Display],
        mainID: DisplayID?
    ) -> [SpaceID: DisplayID] {
        let ordered = PositionalDisplays.ordered(displays, mainID: mainID)
        guard !ordered.isEmpty else { return [:] }
        let plan = frozenPlan[min(ordered.count, frozenPlan.count) - 1]
        var assignment: [SpaceID: DisplayID] = [:]
        for (screen, numbers) in plan.enumerated() {
            for number in numbers {
                assignment[SpaceID(number)] = ordered[screen].id
            }
        }
        var next = (plan.last?.upperBound ?? 0) + 1
        for screen in plan.count..<ordered.count {
            assignment[SpaceID(next)] = ordered[screen].id
            next += 1
        }
        return assignment
    }

    /// Each screen's Space numbers, per connected-screen count up to
    /// three, main screen first.
    private static let frozenPlan: [[ClosedRange<Int>]] = [
        [1...4],
        [1...4, 5...8],
        [1...4, 5...7, 8...10],
    ]
}
