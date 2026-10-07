import KiwiDeskCore
import SwiftUI

/// The way back to What's new after a spotlight row's "Show me"
/// (#2038 ruling ▸ handoff): the search notice's surface, the
/// paused banner's buttons. It stays through navigation inside
/// Settings, with no timeout; ×, Back and the window's close end
/// it (`SettingsModel+WhatsNewTrail`).
struct WhatsNewTrailBanner: View {
    let trail: WhatsNewTrail
    let next: () -> Void
    let back: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(WhatsNewTrailWords.from)
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Absent on the last linked row, never greyed.
            if let stop = trail.next {
                Button(WhatsNewTrailWords.next(stop.title), action: next)
                    .settingsActionButton()
                    .controlSize(.small)
            }
            Button(WhatsNewTrailWords.back, action: back)
                .settingsActionButton()
                .controlSize(.small)
            Button(action: dismiss) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(WhatsNewTrailWords.dismiss)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: SettingsTheme.cardRadius)
                .fill(
                    SettingsTheme.accent.opacity(
                        SettingsTheme.searchNoticeFillOpacity
                    )
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WhatsNewTrailWords.from)
    }
}

/// The banner's words (#2038): its chrome, in the reader's
/// language.
@MainActor
enum WhatsNewTrailWords {
    static var from: String {
        L("whatsnew.trail.from", "From What's new")
    }

    static var back: String {
        L("whatsnew.trail.back", "Back to What's new")
    }

    static var dismiss: String {
        L("whatsnew.trail.dismiss", "Dismiss")
    }

    /// "Next: <row title>" — the title is the notes' English.
    static func next(_ title: String) -> String {
        L("whatsnew.trail.next", "Next: %1$@", title)
    }
}
