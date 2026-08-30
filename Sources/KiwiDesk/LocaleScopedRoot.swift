import KiwiDeskCore
import SwiftUI

/// Rebuilds its content view tree whenever the GUI language changes
/// by mutating the subtree `.id` (#9, HostingRootLocaleScopeTests).
struct LocaleScopedRoot<Content: View>: View {
    @EnvironmentObject private var localization: LocalizationManager

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        // `nil` is "System default" and is a distinct identity
        // from any explicit pick, including explicit English.
        content.id(localization.selection ?? "\u{0}system")
    }
}
