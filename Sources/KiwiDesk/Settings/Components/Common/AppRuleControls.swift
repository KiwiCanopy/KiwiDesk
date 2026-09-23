import KiwiDeskCore
import SwiftUI

/// App picker for the App Rules row.
///
/// Picking IS the add, unconditionally (#1172, #1279): the typed
/// bundle-identifier path was the one exception that rule had,
/// and it is gone. A normal user should not have to type an
/// identifier, and naming an app that is not installed is what
/// Lua's `app_rules` is for — approachable by default, powerful
/// on demand. The escape is now the same file panel the app
/// shortcuts row offers, so one control behaves one way in both
/// places.
///
/// Since #1022 a row cannot be a no-op, so the picker states
/// WHICH rule it composes: the `role` is chosen before the app,
/// and the pick then authors a complete rule. One picker could
/// not — it would have to default to a Space (authoring one
/// nobody chose) or to floating (stopping an app tiling when the
/// user meant it in a Space), and both are rejected in #1022. The
/// gesture stays one click on the app, exactly as #1172 ruled.
struct AppSelector: View {
    /// The rule this picker composes.
    enum Role { case space, float }

    let role: Role
    /// Bundle identifier of chosen app (`AppRef`).
    @Binding var name: String
    /// Bundle IDs to omit — App Rules passes the apps that
    /// already have a rule row, since each app carries at most
    /// one (its space + float facets live on that single row).
    var exclude: Set<String> = []
    /// Called with the bundle id the user committed. The caller
    /// owns normalisation and dedup; this view only says when.
    let onCommit: (String) -> Void

    var body: some View {
        AppPickerButton(
            placeholder: roleLabel,
            selection: name.isEmpty
                ? nil
                : KeybindingCatalog.displayName(
                    forBundleID: name
                ),
            onPick: { app in
                name = app.bundleID
                onCommit(app.bundleID)
            },
            escapeLabel: L(
                "shortcuts.other_ellipsis",
                "Other…"
            ),
            onEscape: {
                if let app = AppBundlePanel.pick() {
                    name = app.bundleID
                    onCommit(app.bundleID)
                }
            },
            exclude: exclude
        )
        // Hug the content (no fixed column to align with) instead
        // of filling the row.
        .fixedSize()
        // The picker is the add affordance, so it carries the
        // census's name — and gives back the choice the name
        // replaces, which for this Button is the text drawn
        // inside it.
        .accessibilityLabel(roleLabel)
        .accessibilityValue(
            name.isEmpty
                ? roleLabel
                : KeybindingCatalog.displayName(forBundleID: name)
        )
    }

    /// Drawn as the button's placeholder and spoken as its name,
    /// from one expression — and the census key for this add
    /// action, authored here where the key scanner can see it.
    private var roleLabel: String {
        switch role {
        case .space:
            return L(
                "app_rules.add_space",
                "Open an app in a Space…"
            )
        case .float:
            return L("app_rules.add_float", "Float an app…")
        }
    }
}
