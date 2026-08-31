import KiwiDeskCore

/// Display order for Layout Defaults settings rows
/// (`LayoutDefaultsCensusRenderTests`,
/// `noRowIsBehindADisclosure`, #678 Phase 3).
enum LayoutDefaultsRowOrder {
    /// Shared minimum window size setting.
    static let general: [SettingKey] = [
        .behaviour(.minWindowSize)
    ]

    static let bsp: [SettingKey] = [
        .layout(.bspStrategy),
        .layout(.bspSplitRatioH),
        .layout(.bspSplitRatioV),
        .layout(.bspNewWindowPlacement),
    ]

    static let stack: [SettingKey] = [
        .layout(.stackMasterCount),
        .layout(.stackMasterRatio),
        .layout(.stackMasterOrientation),
        .layout(.stackStackPosition),
        .layout(.stackOverflowStyle),
        .layout(.stackNewWindowPlacement),
    ]

    /// Scrolling layout settings including focus animations.
    static let scrolling: [SettingKey] = [
        .layout(.scrollingOrientation),
        .layout(.scrollingAnchor),
        .layout(.scrollingSlotSizeUnit),
        .layout(.scrollingSlotSizeValue),
        .layout(.scrollingNewWindowPlacement),
        .layout(.scrollingWrapFocus),
        .colours(.animationsOnScrolling),
        .colours(.animationsScrollDurationMS),
    ]

    static let grid: [SettingKey] = [
        .layout(.gridType),
        .layout(.gridSplitDirection),
        .layout(.gridFillEmptyCells),
        .layout(.gridAutoSize),
        .layout(.gridColumns),
        .layout(.gridRows),
        .layout(.gridNewWindowPlacement),
    ]

    static let monocle: [SettingKey] = [
        .layout(.monocleOrientation),
        .layout(.monocleHideStyle),
        .layout(.monocleWrapFocus),
        .layout(.monocleNewWindowPlacement),
    ]

    static let track: [SettingKey] = [
        .layout(.trackAxis),
        .layout(.trackOverflowStyle),
        .layout(.trackNewWindow),
        .layout(.trackNewWindowPosition),
        .layout(.trackAutoTracks),
        .layout(.trackLimit),
        .layout(.trackWrapFocus),
    ]

    /// Setting rows for specified layout mode (`placementTabs`).
    static func rows(for mode: LayoutMode) -> [SettingKey] {
        switch mode {
        case .bsp: return bsp
        case .stack: return stack
        case .scrolling: return scrolling
        case .grid: return grid
        case .monocle: return monocle
        case .track: return track
        case .floating: return []
        }
    }

    /// Settings container associated with layout mode.
    static func container(
        for mode: LayoutMode
    ) -> SettingsContainer? {
        switch mode {
        case .bsp: return .bsp
        case .stack: return .stack
        case .scrolling: return .scrolling
        case .grid: return .grid
        case .monocle: return .monocle
        case .track: return .track
        case .floating: return nil
        }
    }
}
