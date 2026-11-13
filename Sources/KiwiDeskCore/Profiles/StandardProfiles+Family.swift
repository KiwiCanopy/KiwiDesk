import Foundation

/// The preset family (#3294, owner rulings 2026-11-13): Developer,
/// Focus and Studio across screen counts, Dashboard at two. Slots go
/// widest first, so screen 0 of a plan is the widest screen; no
/// screen holds more than three Spaces on a multi-screen desk, and a
/// small slot holds only laptop-safe layouts. Developer is each
/// count's `isStandard` fallback.
extension StandardProfiles {
    // MARK: - 1 screen

    static let developer1 = preset(
        "Developer",
        isStandard: true,
        screens: [[.stack, .scrolling, .grid, .monocle]]
    )

    static let focus1 = preset(
        "Focus",
        screens: [[.scrolling, .monocle]]
    )

    // MARK: - 2 screens

    static let developer2 = preset(
        "Developer",
        isStandard: true,
        screens: [
            [.stack, .scrolling, .grid],
            [.monocle, .floating, .scrolling],
        ]
    )

    static let dashboard2 = preset(
        "Dashboard",
        screens: [
            [.monocle, .scrolling, .stack],
            [.grid, .scrolling, .floating],
        ]
    )

    static let focus2 = preset(
        "Focus",
        screens: [[.scrolling, .monocle], [.grid]]
    )

    // MARK: - 3 screens

    static let developer3 = preset(
        "Developer",
        isStandard: true,
        screens: [
            [.stack, .scrolling, .grid],
            [.monocle, .floating],
            [.scrolling, .grid],
        ]
    )

    static let studio3 = preset(
        "Studio",
        screens: [
            [.monocle, .floating, .scrolling],
            [.grid, .monocle],
            [.scrolling, .monocle],
        ]
    )

    static let focus3 = preset(
        "Focus",
        screens: [[.scrolling, .monocle], [.grid], [.monocle]]
    )

    // MARK: - 4 screens, offered on every larger desk

    static let developer4 = preset(
        "Developer",
        isStandard: true,
        screens: [
            [.stack, .scrolling, .grid],
            [.monocle, .floating],
            [.scrolling, .grid],
            [.monocle],
        ]
    )

    /// The fourth screen's Space is Grid on a laptop or desktop
    /// screen, Stack on any other.
    static let studio4 = preset(
        "Studio",
        screens: [
            [.monocle, .floating, .scrolling],
            [.grid, .monocle],
            [.scrolling, .monocle],
            [.stack],
        ],
        lastByShape: [.laptop: .grid, .desktop: .grid]
    )

    // MARK: - Builder

    /// A preset from its layouts per screen slot, widest slot
    /// first; Spaces are numbered in that order. `lastByShape`
    /// overrides the last Space's layout on the shapes it names.
    static func preset(
        _ name: String,
        isStandard: Bool = false,
        screens: [[LayoutMode]],
        lastByShape: [ScreenClass: LayoutMode] = [:]
    ) -> StandardLayout {
        var modes: [SpaceID: LayoutMode] = [:]
        var slots: [SpaceID: Int] = [:]
        var next = 1
        for (slot, layouts) in screens.enumerated() {
            for mode in layouts {
                let space = SpaceID(next)
                modes[space] = mode
                if slot > 0 { slots[space] = slot }
                next += 1
            }
        }
        var layout = StandardLayout(
            name: name,
            screenCount: screens.count,
            spaceCount: next - 1,
            spaceModes: modes,
            spaceScreens: slots,
            isStandard: isStandard,
            tuning: .preset(PresetTuning())
        )
        layout.slotsByWidth = true
        if !lastByShape.isEmpty {
            layout.shapeModes = [SpaceID(next - 1): lastByShape]
        }
        return layout
    }
}
