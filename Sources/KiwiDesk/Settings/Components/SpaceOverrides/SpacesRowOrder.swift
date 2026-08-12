/// Display order for the Spaces & Layouts area's rows (#678
/// Phase 3, turn 8). Two containers, both hand-built:
///
/// - `.spaceList` — the space rows themselves (icon, name, layout
///   mode, delete) plus the Show-more fallback space. The list is
///   the screen: one row per space, drawn by `SpacesSection`, not
///   walked from this list.
/// - `.perSpaceOverrides` — the per-space layout override rows
///   (the fields a space's active layout can override) and the two
///   reset actions. The rows and Reset-All are drawn by
///   `SpaceOverrideRows`; the active-layout reset by the editor
///   header (`SpacesSection+Overrides`, #678 8b).
///
/// Both are bespoke: neither container `ForEach`es its order list,
/// so the lists record membership for the placement table and
/// search while `SpacesCensusRenderTests` holds them equal to the
/// census. A row moves by editing the census; the order list
/// follows.
enum SpacesRowOrder {
    /// A space's own controls first (icon, the list itself, name,
    /// layout mode, delete), then the Show-more fallback space.
    static let spaceList: [SettingKey] = [
        .spaces(.spaceIcon),
        .spaces(.spaceList),
        .spaces(.spacesName),
        .spaces(.spaceModes),
        .spaces(.spacesDelete),
        .spaces(.fallbackSpace),
    ]

    /// The override rows grouped by layout mode — the order each
    /// mode's editor stacks them — then the two reset actions the
    /// footer draws below.
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

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .spaceList: spaceList,
        .perSpaceOverrides: perSpaceOverrides,
    ]

    /// Containers drawn as BESPOKE views rather than a `ForEach`
    /// over the list above.
    ///
    /// Both are: the space list is one row per space (drag handle,
    /// icon well, inline rename, layout menu, override cell,
    /// delete), and the override editor switches on the active
    /// layout to a hand-built row set. So the lists exist to record
    /// membership for the placement table and search — the guard
    /// holds that membership — but editing one moves nothing on
    /// screen. A container that becomes a real `ForEach` leaves
    /// this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .spaceList,
        .perSpaceOverrides,
    ]
}
