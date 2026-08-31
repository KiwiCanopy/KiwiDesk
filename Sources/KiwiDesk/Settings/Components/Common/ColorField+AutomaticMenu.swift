import KiwiDeskCore
import SwiftUI

/// Context menu modifier offering "Automatic" reset for adaptive color
/// wells (#429, #845).
extension View {
    /// Context menu and accessibility action resetting color to empty
    /// sentinel (#429).
    @ViewBuilder
    func automaticMenu(
        automatic: Bool,
        hex: Binding<String>,
        draft: Binding<String>
    ) -> some View {
        if automatic {
            rowActions {
                automaticItem(hex: hex, draft: draft)
            }
        } else {
            self
        }
    }

}

/// The one "Automatic" item, built once for every route so a
/// change to what it resets cannot reach only one of them.
@ViewBuilder
private func automaticItem(
    hex: Binding<String>,
    draft: Binding<String>
) -> some View {
    Button {
        hex.wrappedValue = ""
        draft.wrappedValue = ""
    } label: {
        if hex.wrappedValue.isEmpty {
            Label(
                L("color_field.automatic", "Automatic"),
                systemImage: "checkmark"
            )
        } else {
            Text(L("color_field.automatic", "Automatic"))
        }
    }
}
