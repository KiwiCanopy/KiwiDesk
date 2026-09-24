import KiwiDeskCore
import SwiftUI

/// KiwiDesk's own update window (#1542 ruling ▸ Window): a pinned
/// header and footer around the notes, which scroll.
struct UpdateWindowView: View {
    let offer: UpdateOffer
    @ObservedObject var session: UpdateSession
    /// Lays the notes out unscrolled, so the controller can read
    /// their natural height.
    var measuring = false

    var body: some View {
        VStack(spacing: 0) {
            UpdateWindowHeader(offer: offer)
            UpdateNotesScroll(
                offer: offer,
                failed: isFailed,
                measuring: measuring
            )
            UpdateWindowFooter(session: session)
        }
        .frame(width: UpdateWindowMetrics.width)
        // SwiftUI keeps the content below the transparent title
        // bar; only the ground runs up behind the traffic lights.
        .background(SettingsTheme.page.ignoresSafeArea())
        .tint(SettingsTheme.accent)
    }

    private var isFailed: Bool {
        if case .failed = session.phase { return true }
        return false
    }
}

enum UpdateWindowMetrics {
    static let width: CGFloat = 560
    static let minHeight: CGFloat = 420
    static let maxHeight: CGFloat = 640
    /// The transparent title bar the content sits below.
    static let titleBar: CGFloat = 28

    /// The window opens at its content, between the ruled bounds.
    static func height(fitting: CGFloat) -> CGFloat {
        min(max(fitting.rounded(.up), minHeight), maxHeight)
    }
}

private struct UpdateWindowHeader: View {
    let offer: UpdateOffer

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SettingsTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(SettingsTheme.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private var title: String {
        L(
            "update.window.title",
            "KiwiDesk %1$@ is available",
            offer.version
        )
    }

    private var subtitle: String {
        guard let released = offer.released else {
            return L(
                "update.window.installed",
                "You have %1$@",
                offer.installed
            )
        }
        return L(
            "update.window.installed_released",
            "You have %1$@ · Released %2$@",
            offer.installed,
            released.formatted(date: .long, time: .omitted)
        )
    }
}
