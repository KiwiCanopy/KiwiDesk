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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SettingsTheme.ink2)
                .accessibilityAddTraits(.isHeader)
            ForEach(digest.cautions, id: \.version) { caution in
                UpdateNotesEntryText(
                    text: caution.text,
                    version: digest.spansVersions ? caution.version : nil,
                    size: 12.5
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SettingsTheme.groupHeading)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(digest.groups) { group in
                    Button {
                        jump(group.id)
                    } label: {
                        Text(UpdateNotesNaming.counted(group))
                            .underline(color: SettingsTheme.hairline)
                            .foregroundStyle(SettingsTheme.ink2)
                    }
                    .buttonStyle(.plain)
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
    @Binding var expanded: Bool

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

    private var shown: Int {
        UpdateNotesDisclosure.shown(
            of: group.entries.count,
            expanded: expanded
        )
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(
                Array(group.entries.prefix(shown).enumerated()),
                id: \.offset
            ) { _, entry in
                UpdateNotesEntryText(
                    text: entry.text,
                    version: labelled ? entry.version : nil,
                    size: 13
                )
            }
            if shown < group.entries.count {
                Button {
                    expanded = true
                } label: {
                    Text(
                        L(
                            "update.window.show_more",
                            "Show more · %1$d",
                            group.entries.count - shown
                        )
                    )
                    .font(.system(size: 12.5))
                    .foregroundStyle(SettingsTheme.ink2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One entry, with its version label where the view spans several.
struct UpdateNotesEntryText: View {
    let text: String
    let version: String?
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let version {
                Text(version)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(SettingsTheme.ink3)
            }
            Text(UpdateNotesMarkdown.text(text))
                .font(.system(size: size))
                .foregroundStyle(SettingsTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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
        for run in text.runs where run.link != nil {
            text[run.range].underlineStyle = .single
        }
        return text
    }
}
