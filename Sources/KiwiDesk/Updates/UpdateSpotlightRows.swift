import AppKit
import KiwiDeskCore
import SwiftUI

/// The Highlights tab's spotlight (#2038): the intro sentence,
/// then up to four rows. Drawn in place of the prose summary,
/// never beside it.
struct UpdateSpotlightRows: View {
    let digest: UpdateNotesDigest
    /// Failed steps the gold symbols back, as the panel's star.
    let failed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UpdateNotesMarkdown.text(digest.summary))
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(SettingsTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(
                    Array(digest.spotlight.enumerated()),
                    id: \.offset
                ) { _, entry in
                    UpdateSpotlightRow(
                        entry: entry,
                        tag: digest.tag(entry),
                        failed: failed
                    )
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }
}

/// One row: the symbol, the title (tagged with its version when
/// older than the newest), one line, and "Show me" only where the
/// window hands off and this build lands on the row's setting —
/// dropped, never greyed, otherwise. One VoiceOver element.
struct UpdateSpotlightRow: View {
    let entry: UpdateNotesDigest.SpotlightEntry
    let tag: String?
    let failed: Bool

    @Environment(\.spotlightShowMe) private var showMe

    private var row: ReleaseNotes.SpotlightRow { entry.row }

    /// The symbol, where the system knows the name; a name it
    /// does not know draws no icon at all.
    private var symbol: String? {
        guard let name = row.symbol, KiwiCore.iconIsSymbol(name)
        else { return nil }
        return name
    }

    /// The hand-off, where this window offers one and this build
    /// lands on the setting.
    private var link: (() -> Void)? {
        guard let showMe, SpotlightLanding.anchor(for: row.setting) != nil
        else { return nil }
        let entry = entry
        return { showMe(entry) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .regular))
                    // The panel's gold, as its edge and star: accent
                    // marks controls (owner, 2026-10-07).
                    .foregroundStyle(
                        failed ? SettingsTheme.ink3 : SettingsTheme.highlight
                    )
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 1) {
                title
                Text(UpdateNotesMarkdown.text(row.line))
                    .font(.system(size: 13))
                    .foregroundStyle(SettingsTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let link {
                Button(action: link) {
                    HStack(spacing: 3) {
                        Text(UpdateSpotlightWords.showMe)
                            .foregroundStyle(SettingsTheme.ink)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SettingsTheme.ink3)
                    }
                    .font(.system(size: 12.5, weight: .medium))
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .modifier(UpdateSpotlightAction(link: link))
    }

    private var title: some View {
        var text = AttributedString(row.title)
        text.font = .system(size: 14, weight: .semibold)
        text.foregroundColor = SettingsTheme.ink
        if let tag {
            var quiet = AttributedString(UpdateNotesEnglish.rowTag(tag))
            quiet.font = .system(size: 14)
            quiet.foregroundColor = SettingsTheme.ink2
            text += quiet
        }
        return Text(text).fixedSize(horizontal: false, vertical: true)
    }

    /// "Title · 2.1. Line." — the tag is part of the one element.
    private var spoken: String {
        let title = row.title + (tag.map(UpdateNotesEnglish.rowTag) ?? "")
        let line = String(UpdateNotesMarkdown.text(row.line).characters)
        return "\(title). \(line)"
    }
}

/// "Show me" as the row's VoiceOver action, where it has one.
private struct UpdateSpotlightAction: ViewModifier {
    let link: (() -> Void)?

    func body(content: Content) -> some View {
        if let link {
            content.accessibilityAction(
                named: Text(UpdateSpotlightWords.showMe),
                link
            )
        } else {
            content
        }
    }
}

/// The spotlight's chrome, in the reader's language (#2038): the
/// rows stay English like the notes (#1849).
@MainActor
enum UpdateSpotlightWords {
    static var showMe: String {
        L("update.window.spotlight.show_me", "Show me")
    }
}
