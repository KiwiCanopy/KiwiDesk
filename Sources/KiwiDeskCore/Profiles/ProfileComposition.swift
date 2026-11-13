import CoreGraphics
import Foundation

/// Composes fallback layout when no saved profile matches monitors (#53).
public enum ProfileComposition {
    /// A fully resolved fallback layout for a live monitor set.
    public struct Composed: Sendable, Equatable {
        /// The Standard the composition is based on.
        public let sourceName: String
        /// Every defined space, in display order.
        public let spaces: [SpaceID]
        /// Mode per space (dense over `spaces`).
        public let spaceModes: [SpaceID: LayoutMode]
        /// Screen per space (dense over `spaces`).
        public let assignment: [SpaceID: DisplayID]
        /// Unpainted: the apply wears the shared look over it
        /// (#1752), so the GUI never reads it raw.
        let settings: TilingSettings
        /// The starter's title when composed from it (#1662).
        public let sourceTitle: StarterTitle?
    }

    /// Builds fallback composition for connected displays from closest
    /// Standard layout.
    public static func compose(
        displays: [Display],
        mainID: DisplayID?
    ) -> Composed? {
        guard
            let layout = StandardProfiles.standard(
                for: displays.count
            )
        else { return nil }
        return compose(
            layout: layout,
            displays: displays,
            mainID: mainID
        )
    }

    /// Where a Space no pin or role places falls back: the plan the
    /// pre-#3294 Standards drew, kept apart from the preset family
    /// so an upgrade moves no such Space — Spaces 1–4 on the main
    /// screen; 5–8 on a second; with three, 5–7 and 8–10; each
    /// further screen the next number (#3294). The display resolve
    /// and the Settings pictures read this one plan.
    public static func fallbackAssignment(
        displays: [Display],
        mainID: DisplayID?
    ) -> [SpaceID: DisplayID] {
        let ordered = PositionalDisplays.ordered(displays, mainID: mainID)
        let plans: [[ClosedRange<Int>]] = [
            [1...4],
            [1...4, 5...8],
            [1...4, 5...7, 8...10],
        ]
        guard !ordered.isEmpty else { return [:] }
        let plan = plans[min(ordered.count, plans.count) - 1]
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

    /// Composes specific built-in layout onto displays
    /// (`StandardLayout+Screens`).
    public static func compose(
        layout: StandardLayout,
        displays: [Display],
        mainID: DisplayID?
    ) -> Composed? {
        let positional = PositionalDisplays.ordered(
            displays,
            mainID: mainID
        )
        let ordered = layout.slotOrder(
            widths: positional.map(\.frame.width)
        ).map { positional[$0] }
        guard !ordered.isEmpty, layout.spaceCount > 0 else {
            return nil
        }

        var spaces: [SpaceID] = []
        var modes: [SpaceID: LayoutMode] = [:]
        var assignment: [SpaceID: DisplayID] = [:]
        for space in layout.plannedSpaces {
            spaces.append(space)
            let position = layout.screen(
                of: space,
                screens: ordered.count
            )
            modes[space] = layout.mode(
                of: space,
                on: ScreenClass.of(ordered[position])
            )
            assignment[space] = ordered[position].id
        }
        // A screen past the plan holds one Space (#3294).
        let besideUltrawide = StarterAllocation.hasUltrawideCompanion(
            ordered.map(\.frame.size)
        )
        var next = layout.spaceCount + 1
        for position in layout.screenCount..<ordered.count {
            let space = SpaceID(next)
            next += 1
            spaces.append(space)
            modes[space] = extraScreenMode(
                ScreenClass.of(ordered[position]),
                placed: spaces.dropLast().compactMap { modes[$0] },
                besideUltrawide: besideUltrawide
            )
            assignment[space] = ordered[position].id
        }
        return Composed(
            sourceName: layout.name,
            spaces: spaces,
            spaceModes: modes,
            assignment: assignment,
            settings: layout.settings(
                sizes: positional.map(\.frame.size)
            ),
            sourceTitle: layout.starterTitle
        )
    }

    /// The one Space of a screen past a plan: the starter's
    /// single-Space pick, with the starter's clamp beside an
    /// ultrawide, where a non-ultrawide never scrolls (#1662,
    /// #3294) — the same two steps `fillSingleSpaces` takes.
    static func extraScreenMode(
        _ shape: ScreenClass,
        placed: [LayoutMode],
        besideUltrawide: Bool
    ) -> LayoutMode {
        let pick = StarterAllocation.singleSpaceLayout(
            for: shape,
            placed: placed
        )
        let scrollsHere = !besideUltrawide || shape.isUltrawide
        return pick == .scrolling && !scrollsHere ? .monocle : pick
    }
}
