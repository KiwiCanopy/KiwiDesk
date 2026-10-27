import SwiftUI

/// The bottom inset every section root's scroll content ends with
/// (#2688): the floating save pill's room while it floats, the plain
/// gutter while it docks. Gated on width, never on the pill being up,
/// so a Save at the page's end moves nothing under the pointer.
struct SettingsPageBottom: ViewModifier {
    @Environment(\.settingsWidth) private var width

    func body(content: Content) -> some View {
        content.padding(.bottom, SettingsMetrics.pageBottom(width))
    }
}

extension View {
    /// Ends a section root's scroll content clear of the save pill.
    func settingsPageBottom() -> some View {
        modifier(SettingsPageBottom())
    }
}
