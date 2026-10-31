import SwiftUI

/// One of Simple's own cards (#2737): Advanced's section chrome
/// with no search anchor of its own — Simple has no search. A card
/// Simple borrows whole from Advanced (Open applications) keeps its
/// anchor, which no search reaches while Simple shows.
struct SimpleCard<Content: View>: View {
    let title: String
    var caption: String?
    /// False for a section whose parts are their own cards (the
    /// Space grid, #2777).
    var plated = true
    @ViewBuilder let content: Content

    var body: some View {
        SettingsSection(title, caption: caption, plated: plated) {
            content
        }
    }
}
