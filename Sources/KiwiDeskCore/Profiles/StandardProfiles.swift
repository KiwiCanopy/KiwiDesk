import Foundation

/// A built-in, hardware-agnostic layout for one screen count
/// (#53). Two faces: the count's *Standard* resolves silently
/// when no saved profile matches, and every layout is offered
/// as an applyable *Preset* in the GUI.
public struct StandardLayout: Sendable, Equatable {
    public let name: String
    public let summary: String
    /// How many screens this layout plans for.
    public let screenCount: Int
    /// The spaces the layout defines, ids "1"…"N".
    public let spaceCount: Int
    /// Sparse: any space not listed uses the fallback `bsp`.
    public let spaceModes: [SpaceID: LayoutMode]
    /// Positional screen per space (0 = main display, 1 = next
    /// secondary, …). Sparse: unlisted spaces sit on main.
    public let spaceScreens: [SpaceID: Int]
    /// The count's silent-fallback default ("Standard").
    public let isStandard: Bool
    /// Tuning flavor applied with the layout (gaps etc.).
    public let settings: TilingSettings
}

/// The shipped per-count layouts. Never deletable; a count with
/// no saved user profile falls back to its Standard.
public enum StandardProfiles {
    /// The catalog, ordered by screen count, Standards first.
    public static let all: [StandardLayout] = [
        developer, minimalist, focusStack,
        dualDeveloper, coderAndMonitor,
        commandCenter, visualCreative,
    ]

    /// The layouts planning for exactly `count` screens.
    public static func layouts(
        for count: Int
    ) -> [StandardLayout] {
        all.filter { $0.screenCount == count }
    }

    /// The Standard used as fallback for a live screen count:
    /// the marked default of the closest defined count that is
    /// less than or equal to `count`. Nil below one screen.
    public static func standard(
        for count: Int
    ) -> StandardLayout? {
        all.filter { $0.isStandard && $0.screenCount <= count }
            .max { $0.screenCount < $1.screenCount }
    }

    // MARK: - 1 monitor (4 spaces)

    /// Best-practice single-monitor software development.
    static let developer = StandardLayout(
        name: "Developer",
        summary: "IDE stack, scrolling docs, and a fullscreen "
            + "preview space.",
        screenCount: 1,
        spaceCount: 4,
        spaceModes: ["2": .stack, "3": .scrolling, "4": .monocle],
        spaceScreens: [:],
        isStandard: true,
        settings: flavored(gap: 8)
    )

    /// Spacious, distraction-free writing or reading.
    static let minimalist = StandardLayout(
        name: "Minimalist",
        summary: "Spacious gaps, a scrolling reading space, and "
            + "single-focus work.",
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
        summary: "Two stacked task spaces and a deep-work "
            + "monocle space.",
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
        summary: "Code and docs on the main display; mail, chat, "
            + "and media on the second.",
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
        summary: "Editor and terminals on the main display; "
            + "dashboards and logs on the second.",
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
        summary: "Workspace and docs center, communication left, "
            + "logs and monitoring right.",
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
        summary: "Frontend IDE and previews center, design "
            + "canvas left, inspectors right.",
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
