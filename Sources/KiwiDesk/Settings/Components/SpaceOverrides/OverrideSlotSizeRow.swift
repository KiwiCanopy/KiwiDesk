import KiwiDeskCore
import SwiftUI

/// The one per-space override that is a *pair* of rows, not one
/// (#290): the scrolling slot size is a unit picker plus its value
/// control, but a single `ScrollSize?` — so one inherit checkbox
/// owns both. `OverrideChrome(alignment: .top)` wraps the two-row
/// `VStack` as its content, so the accent bar and dim state span
/// the pair and the checkbox lines up with the first row. The rows
/// themselves are the shared `SlotSizeRows` bound through
/// `overrideValue`, so inherit shows the resolved global value and
/// checking seeds it (no jump) — the same seam every other
/// override row uses, no hand-rolled copy to drift (§5).
struct OverrideSlotSizeRow: View {
    @ObservedObject var model: SettingsModel
    /// Effective scroll orientation for the space, so the value
    /// row reads "Column width" horizontally / "Row height"
    /// vertically off the resolved orientation (#239 pattern).
    let isVertical: Bool
    @Binding var value: ScrollSize?
    /// The inherited value shown while unchecked and seeded on
    /// check — the space's resolved (effective) slot size.
    let global: ScrollSize

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
            alignment: .top,
            help: LayoutHelp.slotSize,
            subject: isVertical
                ? L("slot_size.row_height", "Row height")
                : L("slot_size.column_width", "Column width")
        ) {
            // Tighter than the ~8pt gap between separate override
            // rows: proximity alone reads the unit + value pair as
            // one decision, so no drawn box is needed (design
            // consult) — a box would break the popover's flat
            // single-row rhythm.
            VStack(alignment: .leading, spacing: 6) {
                SlotSizeRows(
                    model: model,
                    size: overrideValue($value, global: global),
                    isVertical: isVertical,
                    part: .both,
                    // Dropdown, not segments: matches the popover's
                    // other override rows on this narrow surface
                    // (#291 compact-surface exception).
                    unitStyle: .menu
                )
            }
        }
    }
}
