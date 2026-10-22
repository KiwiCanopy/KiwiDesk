import CoreGraphics

/// What a Space's scrolled runs draw (#2235): each zone that hides
/// windows with the run it shows. Persistence, the z-order
/// restores, navigation and the visibility verdict all read this
/// one value — the engine records it from the pass it issued.
public struct RunCover: Sendable, Equatable {
    /// One zone that hides windows, and the run it draws.
    public struct Run: Sendable, Equatable {
        public let zone: RunZone
        public let run: ZoneRun
        /// What the weights divide once the shown members' floors
        /// are set aside (`RunZone.runExtra`).
        public let extra: CGFloat

        /// Members shown, in drawn order.
        public var shown: ArraySlice<WindowID> {
            zone.members[run.visible]
        }

        /// Members waiting before the run's first slot.
        public var hiddenBefore: ArraySlice<WindowID> {
            zone.members[..<run.visible.lowerBound]
        }

        /// Members waiting after the run's last slot.
        public var hiddenAfter: ArraySlice<WindowID> {
            zone.members[run.visible.upperBound...]
        }
    }

    public let space: SpaceID
    public let runs: [Run]

    public init(space: SpaceID, runs: [Run]) {
        self.space = space
        self.runs = runs
    }

    /// Hidden window → the shown window at the end it waits beyond;
    /// the window itself is parked at the hide corner.
    public var behind: [WindowID: WindowID] {
        var map: [WindowID: WindowID] = [:]
        for run in runs {
            guard let first = run.shown.first, let last = run.shown.last
            else { continue }
            for id in run.hiddenBefore { map[id] = first }
            for id in run.hiddenAfter { map[id] = last }
        }
        return map
    }

    /// The first shown window of each run that hides any ahead of
    /// it — what `Space.runHeads` stores.
    public var heads: Set<WindowID> {
        Set(
            runs.filter { $0.run.visible.lowerBound > 0 }
                .compactMap { $0.shown.first }
        )
    }

    /// The cover `mode` draws over `tiled`, or nil for a layout
    /// that scrolls no zone.
    public static func of(
        space: SpaceID,
        mode: LayoutMode,
        tiled: [WindowID],
        in context: LayoutContext
    ) -> RunCover? {
        guard let zones = RunZone.zones(mode: mode, tiled: tiled, in: context)
        else { return nil }
        let runs = zones.compactMap { zone -> Run? in
            guard let run = zone.run(in: context), run.hides else {
                return nil
            }
            return Run(
                zone: zone,
                run: run,
                extra: zone.runExtra(in: context) ?? 0
            )
        }
        return RunCover(space: space, runs: runs)
    }
}
