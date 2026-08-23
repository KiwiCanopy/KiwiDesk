import KiwiDeskCore
import SwiftUI

/// The adaptive well's right-click "Automatic" path, split from
/// `ColorField` at the §2.1 ceiling.
extension View {
    /// The right-click clear path for an adaptive well (#429): one
    /// "Automatic" item, checked while the well already is, that
    /// resets the color to the empty sentinel. A no-op wrapper on a
    /// well that has no Automatic concept. This is the discoverable
    /// way back — the swatch click opens the picker (a concrete
    /// pick), and typing an empty value is the other path.
    ///
    /// The same item is also a named VoiceOver action (#678 Phase
    /// 4 pass 10, turn 20a rule 1) and keyboard shortcut (#845).
    /// The typed-empty path meant this was never *unreachable*
    /// without a pointer, unlike the palette and space menus — but
    /// it required knowing that an empty field means automatic,
    /// which is precisely the thing a menu item exists to stop you
    /// having to know.
    @ViewBuilder
    func automaticMenu(
        automatic: Bool,
        hex: Binding<String>,
        draft: Binding<String>
    ) -> some View {
        if automatic {
            contextMenu {
                automaticItem(hex: hex, draft: draft)
            }
            .accessibilityActions {
                automaticItem(hex: hex, draft: draft)
            }
            .contextShortcut {
                automaticItem(hex: hex, draft: draft)
            }
        } else {
            self
        }
    }

    /// The one "Automatic" item, built once for both routes so a
    /// change to what it resets cannot reach only one of them.
    @ViewBuilder
    fileprivate func automaticItem(
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
}
