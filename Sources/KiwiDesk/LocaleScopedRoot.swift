import KiwiDeskCore
import SwiftUI

/// Rebuilds its content whenever the GUI language changes.
///
/// `L(_:_:)` is a plain function, not observable state, so a view
/// that merely *calls* it has no dependency on the current locale
/// and SwiftUI never re-renders it when the language changes. Only
/// the few views that declare `@EnvironmentObject
/// LocalizationManager` did — the sidebar and the General pane —
/// so switching language repainted those two and left every other
/// section in the old language until the app was restarted.
///
/// Applied at each SwiftUI **hosting root** rather than per view,
/// deliberately: a per-view opt-in is one more thing to forget,
/// and forgetting it is invisible until someone switches language
/// mid-session — which is exactly how this survived from #9 to
/// eleven shipped locales. `HostingRootLocaleScopeTests` pins that
/// every root uses it.
///
/// The `.id` change discards and rebuilds the subtree, which is
/// the point: every `L()` in it runs again. View state goes with
/// it (scroll offset, disclosure, focus) — acceptable, and the
/// same trade the menu bar already makes by rebuilding itself on
/// a locale change (#329). Model state is unaffected: the models
/// are owned outside these roots and passed in.
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
