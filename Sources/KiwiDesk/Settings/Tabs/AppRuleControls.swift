import KiwiDeskCore
import SwiftUI

/// An app chooser: a dropdown of installed apps plus a "Custom…"
/// option that reveals a free text field (for apps not in
/// /Applications, or `App:Title` float patterns).
struct AppSelector: View {
    @Binding var name: String
    @State private var custom = false

    var body: some View {
        if custom {
            HStack(spacing: 4) {
                TextField(
                    L("app_selector.app_name", "App name"),
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
            }
        } else {
            Menu {
                ForEach(
                    KeybindingCatalog.installedApps,
                    id: \.self
                ) { app in
                    Button(app) { name = app }
                }
                Divider()
                Button(L("app_selector.custom", "Custom…")) {
                    custom = true
                    name = ""
                }
            } label: {
                Text(
                    name.isEmpty
                        ? L("shortcuts.choose_app", "Choose app…")
                        : name
                )
                .frame(minWidth: 150, alignment: .leading)
            }
            .controlSize(.large)
        }
    }
}

/// A dropdown of the user's defined spaces (spaces can only be
/// assigned to ones that already exist).
struct SpaceMenu: View {
    let spaces: [SpaceID]
    let selected: SpaceID?
    let onPick: (SpaceID) -> Void

    var body: some View {
        Menu {
            ForEach(spaces, id: \.raw) { space in
                Button(space.raw) { onPick(space) }
            }
        } label: {
            Text(
                selected?.raw
                    ?? L("space_menu.placeholder", "Space…")
            )
            .frame(minWidth: 70, alignment: .leading)
        }
        .controlSize(.large)
        .frame(width: 110)
    }
}
