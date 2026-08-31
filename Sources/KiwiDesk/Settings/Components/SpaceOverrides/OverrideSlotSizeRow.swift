import KiwiDeskCore
import SwiftUI

/// Override row pair for scrolling slot size settings (#239, #290, #291).
struct OverrideSlotSizeRow: View {
    @ObservedObject var model: SettingsModel
    let isVertical: Bool
    @Binding var value: ScrollSize?
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
