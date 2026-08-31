import KiwiDeskCore
import SwiftUI

/// App picker with installed apps list and custom bundle ID text entry.
struct AppSelector: View {
    /// Bundle identifier of chosen app (`AppRef`).
    @Binding var name: String
    /// Bundle IDs to omit from the picker.
    var exclude: Set<String> = []
    @State private var custom = false

    var body: some View {
        if custom {
            HStack(spacing: 4) {
                TextField(
                    L(
                        "app_selector.bundle_id",
                        "Bundle identifier"
                    ),
                    text: $name
                )
                .textFieldStyle(.roundedBorder)
                Button {
                    custom = false
                    name = ""
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .iconButtonAffordance(
                    L(
                        "app_selector.clear_custom",
                        "Clear custom app"
                    )
                )
            }
        } else {
            AppPickerButton(
                placeholder: L(
                    "shortcuts.choose_app",
                    "Choose app…"
                ),
                selection: name.isEmpty
                    ? nil
                    : KeybindingCatalog.displayName(
                        forBundleID: name
                    ),
                onPick: { name = $0.bundleID },
                escapeLabel: L("app_selector.custom", "Custom…"),
                onEscape: {
                    custom = true
                    name = ""
                },
                exclude: exclude
            )
            // Hug the content (no fixed column to align with, just
            // the trailing "+" button) instead of filling the row.
            .fixedSize()
        }
    }
}
