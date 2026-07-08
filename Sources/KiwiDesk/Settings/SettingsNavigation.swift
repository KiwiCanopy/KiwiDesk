import SwiftUI

/// Cross-tab navigation for the settings detail pane: the view
/// owning the sidebar selection injects a navigator, and deep
/// sections render quiet links ("Appearance ▸ App Bar") where
/// their prose points at a control that lives on another tab —
/// a pointer the user can follow instead of a dead end.

private struct SettingsNavigateKey: EnvironmentKey {
    static let defaultValue: @MainActor (SettingsDestination) -> Void = { _ in
    }
}

extension EnvironmentValues {
    /// Jumps the settings window to a sidebar destination.
    var settingsNavigate: @MainActor (SettingsDestination) -> Void
    {
        get { self[SettingsNavigateKey.self] }
        set { self[SettingsNavigateKey.self] = newValue }
    }
}

/// A quiet inline tab link in the make-default link's language
/// (underlined caption, hover lift + pointing hand) so every
/// "lives elsewhere" pointer reads and acts the same.
struct CrossReferenceLink: View {
    let title: String
    let destination: SettingsDestination
    @Environment(\.settingsNavigate) private var navigate

    init(_ title: String, to destination: SettingsDestination) {
        self.title = title
        self.destination = destination
    }

    var body: some View {
        Button {
            navigate(destination)
        } label: {
            Text(title).underline()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .linkHover()
    }
}
