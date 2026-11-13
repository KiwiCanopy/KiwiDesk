import CoreGraphics
import Foundation

/// Built-in hardware-agnostic layout specification for a screen count (#53).
public struct StandardLayout: Sendable, Equatable {
    public let name: String
    /// Planned screen count.
    public let screenCount: Int
    /// Number of defined spaces ("1"..."N").
    public let spaceCount: Int
    /// Explicit layout mode per space ID (sparse, defaults to `bsp`).
    public let spaceModes: [SpaceID: LayoutMode]
    /// Screen index assignment per space ID (sparse, defaults to main).
    public let spaceScreens: [SpaceID: Int]
    /// Whether this is the default standard layout for its screen count.
    public let isStandard: Bool
    /// Read only through `settings(sizes:)` (#1663).
    let tuning: Tuning
    /// The starter setup's title; nil for every shipped preset.
    public internal(set) var starterTitle: StarterTitle? = nil
    /// Whether the plan's screen slots go widest first, ties by
    /// position, rather than main first: every preset's (#3294),
    /// so a laptop never takes the big slot.
    public internal(set) var slotsByWidth = false
    /// A Space's mode on a given screen shape, ahead of
    /// `spaceModes` — a preset's slot whose layout depends on the
    /// screen it lands on (#3294).
    var shapeModes: [SpaceID: [ScreenClass: LayoutMode]] = [:]
}

/// Catalog of shipped standard layouts and live hardware presets (#53, #485).
public enum StandardProfiles {
    /// Workflows planned purely by screen count: one family —
    /// Developer, Focus, Studio, and Dashboard at two screens
    /// (#3294) — the 4-screen ones offered on every larger desk.
    public static let workflows: [StandardLayout] = [
        developer1, focus1,
        developer2, dashboard2, focus2,
        developer3, studio3, focus3,
        developer4, studio4,
    ]

    /// The largest planned screen count; a larger desk takes its
    /// presets, one more Space per extra screen.
    public static var largestCount: Int {
        workflows.map(\.screenCount).max() ?? 1
    }

    /// Layout catalog for live screens, leading with the hardware
    /// `Starter` (#678). There is exactly ONE Starter and it is
    /// for the screens you have — a count you are not running
    /// offers the workflow layouts alone. Never the silent
    /// `isStandard` fallback: a live-derived setup is a poor thing
    /// to land in silently on a monitor change (#485).
    public static func all(sizes: [CGSize]) -> [StandardLayout] {
        let starter = StarterSetup.standardLayout(sizes: sizes)
        guard
            let lead = workflows.firstIndex(where: {
                $0.screenCount == starter.screenCount
            })
        else { return workflows + [starter] }
        var catalog = workflows
        catalog.insert(starter, at: lead)
        return catalog
    }

    /// Layouts offered for a screen count, the starter first: the
    /// count's own, or the largest planned count's above it.
    public static func layouts(
        for count: Int,
        sizes: [CGSize]
    ) -> [StandardLayout] {
        let planned = min(count, largestCount)
        let starter = StarterSetup.standardLayout(sizes: sizes)
        // The one Starter is for the screens `sizes` names alone.
        let lead = starter.screenCount == count ? [starter] : []
        return lead + workflows.filter { $0.screenCount == planned }
    }

    /// Standard fallback layout for a screen count (#485). Reads
    /// `workflows`, not the live catalog: the Starter is never
    /// `isStandard`, so the silent fallback needs no screen sizes
    /// and stays answerable anywhere.
    public static func standard(
        for count: Int
    ) -> StandardLayout? {
        workflows
            .filter { $0.isStandard && $0.screenCount <= count }
            .max { $0.screenCount < $1.screenCount }
    }
}
