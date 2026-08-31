/// Display order for Spaces area settings rows
/// (`SpacesCensusRenderTests`, #678 Phase 3).
enum SpacesRowOrder {
    /// Space list item controls and fallback setting.
    static let spaceList: [SettingKey] = [
        .spaces(.spaceIcon),
        .spaces(.spaceList),
        .spaces(.spacesName),
        .spaces(.spaceModes),
        .spaces(.spacesDelete),
        .spaces(.fallbackSpace),
    ]

    /// Per-space override rows grouped by layout mode
    /// (`SpaceOverrideRows`, `SpacesSection+Overrides`).
    static let perSpaceOverrides: [SettingKey] = [
        .layout(.bspOverrideStrategy),
        .layout(.bspOverrideSplitRatioH),
        .layout(.bspOverrideSplitRatioV),
        .layout(.stackOverrideMasterCount),
        .layout(.stackOverrideMasterRatio),
        .layout(.stackOverrideOverflowStyle),
        .layout(.stackOverrideStackPosition),
        .layout(.stackOverrideMasterOrientation),
        .layout(.scrollingOverrideOrientation),
        .layout(.scrollingOverrideAnchor),
        .layout(.scrollingOverrideSlotSize),
        .layout(.gridOverrideType),
        .layout(.gridOverrideFillEmptyCells),
        .layout(.gridOverrideSplitDirection),
        .layout(.gridOverrideColumns),
        .layout(.gridOverrideRows),
        .layout(.monocleOverrideOrientation),
        .layout(.trackOverrideAxis),
        .layout(.trackOverrideLimit),
        .layout(.trackOverrideOverflowStyle),
        .spaces(.spaceOverrideResetActive),
        .spaces(.spaceOverrideResetAll),
    ]

    /// Rows grouped by settings container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .spaceList: spaceList,
        .perSpaceOverrides: perSpaceOverrides,
    ]

    /// Containers rendered as bespoke views: the lists record
    /// membership for the placement table and search, but editing
    /// one moves nothing on screen. A container that becomes a
    /// real `ForEach` leaves this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .spaceList,
        .perSpaceOverrides,
    ]
}
