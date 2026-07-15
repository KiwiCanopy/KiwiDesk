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
                }
            )
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
