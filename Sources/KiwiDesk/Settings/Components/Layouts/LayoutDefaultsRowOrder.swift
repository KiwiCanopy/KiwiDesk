import KiwiDeskCore

/// The Layout Defaults area's display order (turn 10 of the
/// redesign, #678 Phase 3). The census owns *placement* — which
/// container and tier each row sits in — but records no display
/// order, so the renderer declares it here as data.
///
/// `LayoutDefaultsCensusRenderTests` pins each list against the
/// census: every `.layoutDefaults`-area key must appear in
/// exactly the list its placement names, so a census row added
/// or moved without a renderer update is a red test, not a
/// silently missing control.
///
/// **Every list here is at rest.** The area declares no
/// `.showMore` row at all: it is a Power-User-mode area whose whole
/// job is the tuned layouts' parameters, and a disclosure inside
/// a card the reader already opened by choosing its layout would
/// hide a setting behind two doors. That is an obligation, not an
/// observation — `noRowIsBehindADisclosure` fails the moment a
/// census row in this area is tiered `.showMore`, because there
/// is no chrome here that could draw one.
enum LayoutDefaultsRowOrder {
    /// The one row that sits ABOVE the layout strip, because it
    /// governs every layout and silently caps auto-sized grids and
    /// track limits (turn 10). Putting it inside a layout's card
    /// would make it look like that layout's setting.
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

    /// The scrolling animation pair (`animationsOnScrolling` and
    /// its duration) lives in this area rather than in Colours &
    /// Animations: it is the scroll's own timing, not a global
    /// animation, and the census places it here.
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

    /// The rows of one layout's card. Exhaustive over the six
    /// tuned layouts, so a seventh added to `placementTabs` fails
    /// to COMPILE rather than rendering an empty card: Floating
    /// has no tunables and therefore no container, which is why
    /// it returns nothing rather than being absent from the
    /// switch.
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

    /// The census container a layout's card renders, so the
    /// render guard can walk mode → container → census rows
    /// instead of restating the pairing. Floating has no
    /// container: it has nothing to tune.
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
