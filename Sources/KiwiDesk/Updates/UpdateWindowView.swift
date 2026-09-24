import KiwiDeskCore
import SwiftUI

/// What the update window says about the offer, fixed for its
/// lifetime (#1542).
struct UpdateOffer {
    /// The offered version, as displayed.
    let version: String
    /// The running version, as displayed.
    let installed: String
    let released: Date?
    /// Nil when the offered version's notes cannot be read.
    let digest: UpdateNotesDigest?

    /// A version's full release notes on GitHub.
    static func notesURL(for version: String) -> URL {
        SupportLinks.releases
            .appendingPathComponent("tag")
            .appendingPathComponent("v" + version)
    }
}

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
        .background(SettingsTheme.page)
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
    /// Room for the transparent title bar's traffic lights.
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
        .padding(.top, UpdateWindowMetrics.titleBar + 4)
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
