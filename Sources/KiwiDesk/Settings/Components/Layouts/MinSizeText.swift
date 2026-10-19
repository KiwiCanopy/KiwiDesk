import KiwiDeskCore

/// A per-layout minimum window size axis's name (#2237): the
/// census text of each follower row, the field's spoken name and
/// the unsaved-changes row's label. One key per sentence so no
/// locale has to agree a layout's name with an axis.
enum MinSizeText {
    @MainActor static func name(
        _ layout: MinWindowSizes.Layout,
        _ axis: MinSizeAxis
    ) -> String {
        switch (layout, axis) {
        case (.stack, .width):
            return L("layout_defaults.min_size.stack_width", "Stack width")
        case (.stack, .height):
            return L("layout_defaults.min_size.stack_height", "Stack height")
        case (.grid, .width):
            return L("layout_defaults.min_size.grid_width", "Grid width")
        case (.grid, .height):
            return L("layout_defaults.min_size.grid_height", "Grid height")
        case (.track, .width):
            return L("layout_defaults.min_size.track_width", "Track width")
        case (.track, .height):
            return L("layout_defaults.min_size.track_height", "Track height")
        case (.bsp, .width):
            return L("layout_defaults.min_size.bsp_width", "BSP width")
        case (.bsp, .height):
            return L("layout_defaults.min_size.bsp_height", "BSP height")
        case (.scrolling, .width):
            return L(
                "layout_defaults.min_size.scrolling_width",
                "Scrolling width"
            )
        case (.scrolling, .height):
            return L(
                "layout_defaults.min_size.scrolling_height",
                "Scrolling height"
            )
        case (.floating, .width):
            return L(
                "layout_defaults.min_size.floating_width",
                "Floating width"
            )
        case (.floating, .height):
            return L(
                "layout_defaults.min_size.floating_height",
                "Floating height"
            )
        }
    }

    /// The census follower naming `layout`'s `axis`.
    static func key(
        _ layout: MinWindowSizes.Layout,
        _ axis: MinSizeAxis
    ) -> BehaviourKey {
        switch (layout, axis) {
        case (.stack, .width): return .minSizeStackWidth
        case (.stack, .height): return .minSizeStackHeight
        case (.grid, .width): return .minSizeGridWidth
        case (.grid, .height): return .minSizeGridHeight
        case (.track, .width): return .minSizeTrackWidth
        case (.track, .height): return .minSizeTrackHeight
        case (.bsp, .width): return .minSizeBspWidth
        case (.bsp, .height): return .minSizeBspHeight
        case (.scrolling, .width): return .minSizeScrollingWidth
        case (.scrolling, .height): return .minSizeScrollingHeight
        case (.floating, .width): return .minSizeFloatingWidth
        case (.floating, .height): return .minSizeFloatingHeight
        }
    }

    /// Every follower, layout by layout.
    static let followers: [BehaviourKey] =
        MinWindowSizes.Layout.allCases.flatMap { layout in
            MinSizeAxis.allCases.map { key(layout, $0) }
        }
}
