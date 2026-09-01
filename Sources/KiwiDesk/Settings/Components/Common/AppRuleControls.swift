import KiwiDeskCore
import SwiftUI

/// App picker with installed apps list and custom bundle ID text entry.
///
/// Picking from the list IS the add — there is no separate
/// confirm, because choosing an app already says everything
/// (#1172). Free text cannot work that way: every keystroke of
/// `com.apple.Safari` is a prefix of it, so the typed path keeps
/// a commit and is the one exception the issue rules.
struct AppSelector: View {
    /// Bundle identifier of chosen app (`AppRef`).
    @Binding var name: String
    /// Bundle IDs to omit — App Rules passes the apps that
    /// already have a rule row, since each app carries at most
    /// one (its space + float facets live on that single row).
    var exclude: Set<String> = []
    /// Called with the bundle id the user committed. The caller
    /// owns normalisation and dedup; this view only says when.
    let onCommit: (String) -> Void
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
                .onSubmit(commitCustom)
                Button(action: commitCustom) {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(name.trimmed.isEmpty)
                .iconButtonAffordance(
                    L("app_rules.add_rule", "Add app rule")
                )
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
                onPick: { app in
                    name = app.bundleID
                    onCommit(app.bundleID)
                },
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
            // The picker is the add affordance now that the
            // button is gone, so it carries the census's name —
            // and gives back the choice the name replaces, which
            // for this Button is the text drawn inside it.
            .accessibilityLabel(
                L("app_rules.add_rule", "Add app rule")
            )
            .accessibilityValue(
                name.isEmpty
                    ? L("shortcuts.choose_app", "Choose app…")
                    : KeybindingCatalog.displayName(
                        forBundleID: name
                    )
            )
        }
    }

    private func commitCustom() {
        guard !name.trimmed.isEmpty else { return }
        onCommit(name)
        custom = false
    }
}
