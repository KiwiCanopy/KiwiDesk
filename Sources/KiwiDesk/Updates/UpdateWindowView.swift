import KiwiDeskCore
import SwiftUI

/// What the window is for: an offer Sparkle is waiting on, or
/// the notes of an update already installed (#1542 ruling ▸ After
/// the update).
enum UpdateWindowMode {
    case offer(UpdateSession)
    case whatsNew(done: () -> Void)
}

/// KiwiDesk's own update window (#1542 ruling ▸ Window): a pinned
/// header and footer around the notes, which scroll.
struct UpdateWindowView: View {
    let offer: UpdateOffer
    let mode: UpdateWindowMode
    /// Lays the notes out unscrolled, so the controller can read
    /// their natural height.
    var measuring = false

    var body: some View {
        switch mode {
        case .offer(let session):
            UpdateOfferLayout(
                offer: offer,
                session: session,
                measuring: measuring
            )
        case .whatsNew(let done):
            UpdateWindowLayout(
                offer: offer,
                whatsNew: true,
                failed: false,
                measuring: measuring
            ) {
                WhatsNewFooter(done: done)
            }
        }
    }
}

/// The offer's layout, observing the session for its footer and
/// the Failed step-back of the Highlights gold.
private struct UpdateOfferLayout: View {
    let offer: UpdateOffer
    @ObservedObject var session: UpdateSession
    let measuring: Bool

    var body: some View {
        UpdateWindowLayout(
            offer: offer,
            whatsNew: false,
            failed: isFailed,
            measuring: measuring
        ) {
            UpdateWindowFooter(session: session)
        }
    }

    private var isFailed: Bool {
        if case .failed = session.phase { return true }
        return false
    }
}

private struct UpdateWindowLayout<Footer: View>: View {
    let offer: UpdateOffer
    let whatsNew: Bool
    let failed: Bool
    let measuring: Bool
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            UpdateWindowHeader(offer: offer, whatsNew: whatsNew)
            UpdateNotesScroll(
                offer: offer,
                failed: failed,
                whatsNew: whatsNew,
                measuring: measuring
            )
            footer()
        }
        .frame(width: UpdateWindowMetrics.width)
        // SwiftUI keeps the content below the transparent title
        // bar; only the ground runs up behind the traffic lights.
        .background(SettingsTheme.page.ignoresSafeArea())
        .tint(SettingsTheme.accent)
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
    let whatsNew: Bool

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
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(SettingsTheme.ink2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private var title: String {
        if whatsNew {
            return L(
                "update.window.whats_new_title",
                "What's new in KiwiDesk %1$@",
                offer.version
            )
        }
        return L(
            "update.window.title",
            "KiwiDesk %1$@ is available",
            offer.version
        )
    }

    private var subtitle: String {
        if whatsNew {
            guard let released = offer.released else { return "" }
            return L(
                "update.window.released",
                "Released %1$@",
                released.formatted(date: .long, time: .omitted)
            )
        }
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
