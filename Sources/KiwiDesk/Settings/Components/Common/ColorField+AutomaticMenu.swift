import KiwiDeskCore
import SwiftUI

/// Context menu modifier offering "Automatic" reset for adaptive color
/// wells (#429, #845).
extension View {
    /// Context menu and accessibility action resetting color to the
    /// empty "Automatic" sentinel (#429); a no-op wrapper on wells
    /// with no Automatic concept. Also a named VoiceOver action
    /// (#678) and keyboard shortcut (#845).
    @ViewBuilder
    @MainActor
    func automaticMenu(
        automatic: Bool,
        clearable: Bool = false,
        hex: Binding<String>,
        draft: Binding<String>
    ) -> some View {
        if automatic || clearable {
            rowActions {
                if automatic { automaticItem(hex: hex, draft: draft) }
                if clearable { noColourItem(hex: hex, draft: draft) }
            }
        } else {
            self
        }
    }

}

/// The one "Automatic" item, built once for every route so a
/// change to what it resets cannot reach only one of them.
@ViewBuilder
@MainActor
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

/// "No Colour" (#2569): the Fill at zero opacity, its hue kept so
/// raising the opacity brings the colour back.
@ViewBuilder
@MainActor
private func noColourItem(
    hex: Binding<String>,
    draft: Binding<String>
) -> some View {
    Button {
        hex.wrappedValue = KiwiShelf.cleared(hex.wrappedValue)
        draft.wrappedValue = ""
    } label: {
        if !KiwiShelf.hasColour(hex.wrappedValue) {
            Label(
                L("color_field.no_color", "No Color"),
                systemImage: "checkmark"
            )
        } else {
            Text(L("color_field.no_color", "No Color"))
        }
    }
}
