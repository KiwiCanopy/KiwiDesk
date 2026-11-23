import KiwiDeskCore
import SwiftUI

/// The shortcuts sheet (#326, #820) as the key panel's Shortcuts
/// side draws it (#2246): titled sections — each Controls group,
/// then Apps, Custom and Inactive — in one column or in the
/// column-major columns KiwiHub's plan cuts them into (#3570 ▸
/// Ruling 5), and Unavailable last, across the whole sheet below
/// them. Section titles are the one heading level, and a section the
/// query empties is dropped.
struct ShortcutsSheetView: View {
    /// What the sheet shows; nil where `init.lua` owns the
    /// shortcuts.
    let reference: ShortcutsReference?
    /// The typed query, drawn bold in each row's name.
    let needle: String
    /// Each column's pieces of the column sections; empty draws one
    /// column of them whole.
    var columns: [[ShortcutsColumnPlan.Piece]] = []

    var body: some View {
        if let reference, !reference.isEmpty {
            let all = Self.sections(reference, needle: needle)
            let flowing = all.filter { !$0.closes }
            let cut = Self.cut(columns, over: flowing)
            let closing = all.filter(\.closes)
            // One column sizes its chords over every row, the closing
            // section's too, so all its dividers share one x (#3424).
            let single = cut.count == 1
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Self.columnGap) {
                    ForEach(Array(cut.enumerated()), id: \.offset) {
                        _,
                        pieces in
                        column(flowing, pieces, sized: !single)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // VoiceOver reads a column whole before the
                            // next.
                            .accessibilityElement(children: .contain)
                    }
                }
                ForEach(closing, id: \.title) { section in
                    sectionView(section, rows: section.rows, title: .whole)
                        .padding(
                            .top,
                            flowing.isEmpty
                                ? 0 : ShortcutsColumnPlan.sectionGap
                        )
                        .modifier(
                            Self.chordColumns(single ? nil : section.rows)
                        )
                }
            }
            .modifier(
                Self.chordColumns(
                    single ? (flowing + closing).flatMap(\.rows) : nil
                )
            )
            .environment(\.shortcutMatch, needle)
        } else {
            placeholder
        }
    }

    /// The room between two columns.
    static let columnGap: CGFloat = 24
    /// A row's height, and the stack's spacing between a section's
    /// parts; the column plan's estimate reads both.
    static let rowHeight: CGFloat = 26
    static let partSpacing: CGFloat = 2
    /// The room under a section's title and under its caption.
    static let titleGap: CGFloat = 2
    static let captionGap: CGFloat = 4

    /// One column's pieces.
    /// `sized`: the column measures its own chords; else the sheet
    /// around it does.
    private func column(
        _ sections: [Section],
        _ pieces: [ShortcutsColumnPlan.Piece],
        sized: Bool
    ) -> some View {
        let rows = pieces.flatMap { Array(sections[$0.section].rows[$0.rows]) }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                let section = sections[piece.section]
                sectionView(
                    section,
                    rows: Array(section.rows[piece.rows]),
                    title: piece.continued ? .continued : .whole
                )
                .padding(.top, index == 0 ? 0 : ShortcutsColumnPlan.sectionGap)
            }
        }
        .modifier(Self.chordColumns(sized ? rows : nil))
    }

    /// How a piece draws its section's head: whole, or the title
    /// alone in tertiary ink over rows continued from the column
    /// before.
    enum Head { case whole, continued }

    /// One titled run of rows.
    struct Section {
        let title: String
        let rows: [ShortcutRow]
        /// What the whole list has in common, under the title.
        var caption: String? = nil
        /// Whether the section dims its rows; an unavailable row
        /// dims itself.
        var dims = false
        /// Whether it closes the sheet across its whole width, below
        /// the columns (#3570 ▸ Ruling 5).
        var closes = false
    }

    /// The sheet's sections, in reading order. Unavailable shows only
    /// while `needle` searches and matches it (owner, 2026-11-23):
    /// an empty query keeps keys that do nothing off the glance.
    static func sections(
        _ reference: ShortcutsReference,
        needle: String = ""
    ) -> [Section] {
        var out = reference.controls.map {
            Section(title: $0.title, rows: $0.rows)
        }
        out.append(
            Section(
                title: ShortcutGroup.apps.title,
                rows: reference.apps
            )
        )
        // A binding's own groups, untranslated (#2544).
        out += reference.groups.map {
            Section(title: $0.title, rows: $0.rows)
        }
        out.append(
            Section(
                title: ShortcutGroup.personalTitle,
                rows: reference.custom
            )
        )
        out.append(
            Section(
                title: L(
                    "shortcuts.section.inactive",
                    "Inactive shortcuts"
                ),
                rows: reference.inactive,
                caption: inactiveCaption,
                dims: true
            )
        )
        guard !needle.isEmpty else { return out.filter { !$0.rows.isEmpty } }
        out.append(
            Section(
                title: L(
                    "shortcuts.section.unavailable",
                    "Unavailable shortcuts"
                ),
                rows: reference.desktopAway,
                caption: KeybindingCatalog.desktopAwayCaption,
                closes: true
            )
        )
        return out.filter { !$0.rows.isEmpty }
    }

    private func sectionView(
        _ section: Section,
        rows: [ShortcutRow],
        title head: Head
    ) -> some View {
        VStack(alignment: .leading, spacing: Self.partSpacing) {
            Text(section.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(head == .whole ? .secondary : .tertiary)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Self.titleGap)
            // A filtered row's dimming and hint already say it; the
            // caption is for the whole list.
            // Unavailable, shown only under a query, keeps its caption.
            if head == .whole, let caption = section.caption,
                needle.isEmpty || section.closes
            {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Self.captionGap)
            }
            ForEach(rows) { row in
                ShortcutRowView(row: row)
                    .frame(height: Self.rowHeight)
            }
            .opacity(section.dims ? 0.6 : 1)
            // A section with no chord keeps no chord slot and no
            // divider: its badges sit at the column's edge (#3570).
            .transformEnvironment(\.shortcutColumns) {
                $0 = Self.columns($0, keeping: section.rows)
            }
        }
    }

    /// Settings' own section says the same thing and then adds
    /// "rebind or remove them here" — which this sheet cannot
    /// offer, so the two captions are different strings.
    private static var inactiveCaption: String {
        L(
            "shortcuts.panel.inactive.caption",
            "These target Spaces that are not in the current "
                + "Space list. They still work — pressing one "
                + "recreates its Space — and they come back "
                + "when their Space returns."
        )
    }

    /// The empty sheet: nothing matches, nothing bound, or an
    /// `init.lua` that owns the shortcuts has not loaded (#2482).
    private var placeholder: some View {
        Text(placeholderText)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    private var placeholderText: String {
        guard reference != nil else {
            return L(
                "shortcuts.panel.unavailable",
                "Your init.lua\u{2019}s shortcuts appear here once "
                    + "KiwiDesk loads it."
            )
        }
        guard needle.isEmpty else {
            return L("shortcuts.panel.no_match", "No shortcuts match")
        }
        return L("shortcuts.panel.empty", "No shortcuts bound yet.")
    }
}

private struct ShortcutMatchKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    /// The Shortcuts side's typed query, drawn bold in each row.
    var shortcutMatch: String {
        get { self[ShortcutMatchKey.self] }
        set { self[ShortcutMatchKey.self] = newValue }
    }
}
