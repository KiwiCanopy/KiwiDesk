import SwiftUI

/// One of Simple's own cards (#2737): Advanced's section chrome,
/// unanchored — Simple has no search, and Advanced's cards keep the
/// ids a search lands on.
struct SimpleCard<Content: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder let content: Content

    var body: some View {
        SettingsSection(title, caption: caption) { content }
    }
}
