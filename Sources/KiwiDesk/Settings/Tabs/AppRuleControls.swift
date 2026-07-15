import KiwiDeskCore
import SwiftUI

/// An app chooser: a dropdown of installed apps (identified by
/// bundle id, shown by localized name) plus a "Custom…" option
/// that reveals a free text field for a bundle id an app that
/// isn't installed right now would use.
struct AppSelector: View {
    /// The bundle identifier of the chosen app — the stored
    /// identity (see `AppRef`), not the display name.
    @Binding var name: String
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
            }
        } else {
            Menu {
                ForEach(
                    KeybindingCatalog.installedApps
                ) { app in
                    Button(app.name) { name = app.bundleID }
                }
                Divider()
                Button(L("app_selector.custom", "Custom…")) {
                    custom = true
                    name = ""
                }
            } label: {
                menuLabel(
                    name.isEmpty
                        ? L("shortcuts.choose_app", "Choose app…")
                        : KeybindingCatalog.displayName(
                            forBundleID: name
                        )
                )
                .frame(minWidth: 150, alignment: .leading)
            }
            .controlSize(.large)
        }
    }
}

/// The borderless-menu signature (`ProfileEditTargetMenu`): a
/// trailing chevron on the label so a bare-text menu still reads
/// as "this opens a menu".
private func menuLabel(_ text: String) -> some View {
    HStack(spacing: 4) {
        Text(text)
        Image(systemName: "chevron.up.chevron.down")
            .font(.caption2)
            .foregroundStyle(.secondary)
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
            menuLabel(
                selected?.raw
                    ?? L("space_menu.placeholder", "Space…")
            )
            .frame(minWidth: 70, alignment: .leading)
        }
        .controlSize(.large)
        .frame(width: 110)
    }
}
