import KiwiDeskCore
import SwiftUI

/// New-window placement picker shared by every layout (BSP,
/// Stack, Scrolling, Grid).
struct PlacementPicker: View {
    @Binding var placement: SpawnPlacement
    /// Row label; defaults to "New window". Track passes
    /// "Position" — it already has a separate own/focused mode
    /// row above, so a second "New window" would read wrong.
    var label: String? = nil
    /// Help override for callers whose picker means something
    /// else — Track positions a whole track in own-track mode,
    /// so the window-centric default would lie there.
    var help: String? = nil

    var body: some View {
        let rowLabel = label ?? newWindowLabel
        return DropdownRow(
            label: rowLabel,
            help: help ?? LayoutHelp.newWindowPlacement
        ) {
            Picker(rowLabel, selection: $placement) {
                Text(L("placement.first", "First"))
                    .tag(SpawnPlacement.first)
                Text(L("placement.last", "Last"))
                    .tag(SpawnPlacement.last)
                Text(
                    L(
                        "placement.before_focused",
                        "Before focused"
                    )
                )
                .tag(SpawnPlacement.beforeFocused)
                Text(
                    L(
                        "placement.after_focused",
                        "After focused"
                    )
                )
                .tag(SpawnPlacement.afterFocused)
            }
        }
    }

    private var newWindowLabel: String {
        L("placement.new_window", "New window")
    }
}
