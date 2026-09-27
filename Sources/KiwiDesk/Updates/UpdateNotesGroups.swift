import KiwiDeskCore
import SwiftUI

/// The newest summary in one gold-edged panel, with every merged
/// version's "Before you update" beneath it (#1542 ruling).
struct UpdateHighlightsPanel: View {
    let digest: UpdateNotesDigest
    /// Failed steps the gold back to a plain card.
    let failed: Bool
    /// After the update the cautions are past advice, so their
    /// label reads "Good to know" (owner, 2026-09-24).
    let whatsNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            label
            Text(UpdateNotesMarkdown.text(digest.summary))
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(SettingsTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !digest.cautions.isEmpty { cautions }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ground)
        .overlay(edge)
        .accessibilityElement(children: .contain)
    }

    private var label: some View {
        Label {
            Text(L("update.window.highlights", "Highlights"))
                .textCase(.uppercase)
                .tracking(0.9)
        } icon: {
            Image(systemName: "star.fill")
                .foregroundStyle(
                    failed ? SettingsTheme.ink3 : SettingsTheme.highlight
                )
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(SettingsTheme.ink2)
        .accessibilityAddTraits(.isHeader)
    }

    private var cautions: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(cautionsLabel)
                .textCase(.uppercase)
                .tracking(0.66)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SettingsTheme.ink2)
                .accessibilityAddTraits(.isHeader)
            ForEach(digest.cautions, id: \.version) { caution in
                UpdateNotesEntryText(
                    text: caution.text,
                    version: digest.spansVersions ? caution.version : nil,
                    size: 12.5,
                    bulleted: false
                )
            }
        }
        .padding(.top, 9)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    failed
                        ? SettingsTheme.hairline
                        : SettingsTheme.highlight.opacity(0.35)
                )
                .frame(height: 1)
        }
        .padding(.top, 3)
    }

    private var cautionsLabel: String {
        whatsNew
            ? L("update.window.good_to_know", "Good to know")
            : L("update.window.before_you_update", "Before you update")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    @ViewBuilder private var ground: some View {
        shape.fill(SettingsTheme.card)
        if !failed {
            shape.fill(
                SettingsTheme.highlight.opacity(
                    SettingsTheme.highlightWashOpacity
                )
            )
        }
    }

    private var edge: some View {
        shape.strokeBorder(
            failed ? SettingsTheme.hairline : SettingsTheme.highlight,
            lineWidth: failed ? 1 : 1.5
        )
    }
}

/// One type's changes, the body of its tab: every entry, flat.
struct UpdateNotesGroupList: View {
    let group: UpdateNotesDigest.Group
    /// Entries carry their version when the view spans several.
    let labelled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(
                Array(group.entries.enumerated()),
                id: \.offset
            ) { _, entry in
                UpdateNotesEntryText(
                    text: entry.text,
                    version: labelled ? entry.version : nil,
                    size: 13
                )
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One entry, with its version label where the view spans several.
struct UpdateNotesEntryText: View {
    let text: String
    let version: String?
    let size: CGFloat
    /// Changes are a bulleted list; a caution is a paragraph.
    var bulleted = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if bulleted {
                Text(verbatim: "•")
                    .foregroundStyle(SettingsTheme.ink3)
                    .accessibilityHidden(true)
            }
            Text(UpdateNotesMarkdown.entry(text, version: version))
                .lineSpacing(3)
                .foregroundStyle(SettingsTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: size))
    }
}

/// The name the window draws for a group.
@MainActor
enum UpdateNotesNaming {
    /// A known type in the reader's language; any other under the
    /// title the feed carries.
    static func name(_ group: UpdateNotesDigest.Group) -> String {
        switch group.kind {
        case .new: return L("update.window.group.new", "New")
        case .improved:
            return L("update.window.group.improved", "Improved")
        case .fixed: return L("update.window.group.fixed", "Fixed")
        case .scripting:
            return L("update.window.group.scripting", "Lua & CLI")
        case nil: return group.title
        }
    }
}
