import KiwiDeskCore
import SwiftUI

/// The newest summary in one gold-edged panel, with every merged
/// version's "Before you update" beneath it (#1542 ruling).
struct UpdateHighlightsPanel: View {
    let digest: UpdateNotesDigest
    /// Failed steps the gold back to a plain card.
    let failed: Bool

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
            Text(L("update.window.before_you_update", "Before you update"))
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

/// "All changes · N" and one link per group that opens it.
struct UpdateNotesTally: View {
    let digest: UpdateNotesDigest
    let jump: (String) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(
                L(
                    "update.window.all_changes",
                    "All changes · %1$d",
                    digest.total
                )
            )
            .textCase(.uppercase)
            .tracking(0.66)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SettingsTheme.groupHeading)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            // Wraps: a long locale or a feed-titled group must not
            // truncate the run.
            FlowLayout(spacing: 12) {
                ForEach(digest.groups) { group in
                    Button {
                        jump(group.id)
                    } label: {
                        Text(UpdateNotesNaming.counted(group))
                            .underline(color: SettingsTheme.hairline)
                            .foregroundStyle(SettingsTheme.ink2)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .accessibilityHint(
                        L(
                            "update.window.jump_hint",
                            "Opens this group of changes."
                        )
                    )
                }
            }
            .font(.system(size: 12))
        }
        .padding(.top, 6)
    }
}

/// One type's changes as a disclosure: symbol and "Name · N", no
/// hue; an open group shows its first entries and "Show more".
struct UpdateNotesGroupCard: View {
    let group: UpdateNotesDigest.Group
    /// Entries carry their version when the view spans several.
    let labelled: Bool
    @Binding var open: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            entries
        } label: {
            Label {
                Text(UpdateNotesNaming.counted(group))
            } icon: {
                Image(systemName: UpdateNotesNaming.symbol(group))
                    .foregroundStyle(SettingsTheme.ink2)
            }
        }
        .disclosureGroupStyle(SettingsDisclosureStyle())
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SettingsTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(SettingsTheme.hairline)
        )
    }

    private var entries: some View {
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

/// Names and symbols the window draws for a group.
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

    /// "Name · N" — the count last, so no locale agrees with it.
    static func counted(_ group: UpdateNotesDigest.Group) -> String {
        L(
            "update.window.group_count",
            "%1$@ · %2$d",
            name(group),
            group.entries.count
        )
    }

    static func symbol(_ group: UpdateNotesDigest.Group) -> String {
        group.kind?.symbol ?? ReleaseNoteKind.otherSymbol
    }
}

/// An entry followed by its version in brackets, which only a
/// window spanning several versions passes (owner, 2026-09-24).
/// One localized frame, since the brackets are punctuation a
/// locale may write differently; the version is drawn quieter.
extension UpdateNotesMarkdown {
    @MainActor
    static func entry(_ markdown: String, version: String?)
        -> AttributedString
    {
        var text = self.text(markdown)
        guard let version else { return text }
        let frame = L("update.window.entry_version", "%1$@ (%2$@)")
        let parts = frame.components(separatedBy: "%1$@")
        guard parts.count == 2 else { return text }
        // Either side may carry the version, whichever order the
        // locale writes.
        let quiet = parts.map { part -> AttributedString in
            var run = AttributedString(
                part.replacingOccurrences(of: "%2$@", with: version)
            )
            run.foregroundColor = SettingsTheme.ink3
            return run
        }
        text = quiet[0] + text + quiet[1]
        return text
    }
}

/// The feed's entries are inline markdown — bold, emphasis, code
/// and links, the subset `appcast-sync`'s `inline` renders.
enum UpdateNotesMarkdown {
    /// Links are underlined so they read as links in the ink
    /// colour rather than the accent, which marks fills only.
    static func text(_ markdown: String) -> AttributedString {
        guard
            var text = try? AttributedString(
                markdown: markdown,
                options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
        else { return AttributedString(markdown) }
        for run in text.runs {
            if run.link != nil {
                text[run.range].underlineStyle = .single
            }
            if run.inlinePresentationIntent?.contains(.code) == true {
                text[run.range].backgroundColor = SettingsTheme.sunken
            }
        }
        return text
    }
}
