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
    /// Associated tiling settings.
    public let settings: TilingSettings
}

/// Catalog of shipped standard layouts and live hardware presets (#53, #485).
public enum StandardProfiles {
    /// Workflows planned purely by screen count.
    public static let workflows: [StandardLayout] = [
        developer, minimalist, focusStack,
        dualDeveloper, coderAndMonitor,
        commandCenter, visualCreative,
    ]

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

    /// Layouts matching exact screen count for given screen sizes.
    public static func layouts(
        for count: Int,
        sizes: [CGSize]
    ) -> [StandardLayout] {
        all(sizes: sizes).filter { $0.screenCount == count }
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

    // MARK: - 1 monitor (4 spaces)

    /// Best-practice single-monitor software development.
    static let developer = StandardLayout(
        name: "Developer",
        screenCount: 1,
        spaceCount: 4,
        spaceModes: [
            "1": .grid, "2": .stack, "3": .scrolling, "4": .monocle,
        ],
        spaceScreens: [:],
        isStandard: true,
        settings: flavored(gap: 8)
    )

    /// Spacious, distraction-free writing or reading.
    static let minimalist = StandardLayout(
        name: "Minimalist",
        screenCount: 1,
        spaceCount: 4,
        spaceModes: ["1": .scrolling, "3": .monocle, "4": .floating],
        spaceScreens: [:],
        isStandard: false,
        settings: flavored(gap: 20) { settings in
            settings.scrolling.anchor = .center
        }
    )

    /// Heavy multitasking on stacked panels.
    static let focusStack = StandardLayout(
        name: "Focus Stack",
        screenCount: 1,
        spaceCount: 4,
        spaceModes: ["1": .stack, "2": .stack, "4": .monocle],
        spaceScreens: [:],
        isStandard: false,
        settings: flavored(gap: 10)
    )

    // MARK: - 2 monitors (8 spaces, 1–4 main / 5–8 second)

    /// Production on the main display, communication and
    /// monitoring on the second.
    static let dualDeveloper = StandardLayout(
        name: "Dual Developer",
        screenCount: 2,
        spaceCount: 8,
        spaceModes: [
            "2": .stack, "3": .scrolling, "4": .monocle,
            "6": .stack, "7": .monocle, "8": .floating,
        ],
        spaceScreens: secondaryRange(5...8, screen: 1),
        isStandard: true,
        settings: flavored(gap: 8)
    )

    /// Build logs, metrics, and database viewers on screen two.
    static let coderAndMonitor = StandardLayout(
        name: "Coder & Monitor",
        screenCount: 2,
        spaceCount: 8,
        spaceModes: [
            "2": .stack, "3": .stack, "4": .monocle,
            "5": .stack, "6": .monocle, "7": .floating,
            "8": .floating,
        ],
        spaceScreens: secondaryRange(5...8, screen: 1),
        isStandard: false,
        settings: flavored(gap: 8)
    )

    // MARK: - 3 monitors (10 spaces, 1–4 / 5–7 / 8–10)

    /// Maximum real estate for triple-head setups.
    static let commandCenter = StandardLayout(
        name: "Command Center",
        screenCount: 3,
        spaceCount: 10,
        spaceModes: [
            "2": .stack, "3": .scrolling, "4": .monocle,
            "6": .stack, "7": .monocle,
            "8": .stack, "9": .scrolling, "10": .monocle,
        ],
        spaceScreens: secondaryRange(5...7, screen: 1)
            .merging(
                secondaryRange(8...10, screen: 2)
            ) { first, _ in first },
        isStandard: true,
        settings: flavored(gap: 8)
    )

    /// Design and frontend engineering pipelines.
    static let visualCreative = StandardLayout(
        name: "Visual Creative & Developer",
        screenCount: 3,
        spaceCount: 10,
        spaceModes: [
            "1": .scrolling, "2": .monocle, "4": .floating,
            "5": .monocle, "6": .floating,
            "8": .stack, "9": .monocle, "10": .floating,
        ],
        spaceScreens: secondaryRange(5...7, screen: 1)
            .merging(
                secondaryRange(8...10, screen: 2)
            ) { first, _ in first },
        isStandard: false,
        settings: flavored(gap: 10)
    )

    // MARK: - Helpers

    private static func flavored(
        gap: Double,
        tune: (inout TilingSettings) -> Void = { _ in }
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.gapsGlobal = .uniform(gap)
        tune(&settings)
        return settings
    }

    private static func secondaryRange(
        _ spaces: ClosedRange<Int>,
        screen: Int
    ) -> [SpaceID: Int] {
        var map: [SpaceID: Int] = [:]
        for space in spaces { map[SpaceID(space)] = screen }
        return map
    }
}
