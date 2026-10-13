import KiwiDeskCore
import SwiftUI

/// The shortcuts sheet (#326, #820) as the key panel's Shortcuts
/// side draws it (#2246): one titled column — each Controls group,
/// then Apps, Custom and Inactive last. Section titles are the one
/// heading level, and a section the query empties is dropped.
struct ShortcutsSheetView: View {
    /// What the sheet shows; nil where `init.lua` owns the
    /// shortcuts.
    let reference: ShortcutsReference?
    /// The typed query, drawn bold in each row's name.
    let needle: String

    var body: some View {
        if let reference, !reference.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(
                    Array(sections(reference).enumerated()),
                    id: \.offset
                ) { index, section in
                    sectionView(section, first: index == 0)
                }
            }
            .environment(\.shortcutMatch, needle)
        } else {
            placeholder
        }
    }

    /// One titled run of rows.
    struct Section {
        let title: String
        let rows: [ShortcutRow]
        var inactive = false
    }

    /// The column's sections, in reading order.
    func sections(_ reference: ShortcutsReference) -> [Section] {
        var out = reference.controls.map {
            Section(title: $0.title, rows: $0.rows)
        }
        out.append(
            Section(
                title: L("shortcuts.panel.apps", "Apps"),
                rows: reference.apps
            )
        )
        out.append(
            Section(
                title: L("shortcuts.panel.custom", "Custom"),
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
                inactive: true
            )
        )
        return out.filter { !$0.rows.isEmpty }
    }

    private func sectionView(_ section: Section, first: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 2)
            // A filtered row's dimming and hint already say it; the
            // caption is for the whole list.
            if section.inactive, needle.isEmpty {
                Text(inactiveCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            ForEach(section.rows) { row in
                ShortcutRowView(row: row)
                    .frame(height: 26)
            }
            .opacity(section.inactive ? 0.6 : 1)
        }
        .padding(.top, first ? 0 : 16)
    }

    /// Settings' own section says the same thing and then adds
    /// "rebind or remove them here" — which this sheet cannot
    /// offer, so the two captions are different strings.
    private var inactiveCaption: String {
        L(
            "shortcuts.panel.inactive.caption",
            "These target Spaces that are not in the current "
                + "Space list. They still work — pressing one "
                + "recreates its Space — and they come back "
                + "when their Space returns."
        )
    }

    /// The empty sheet: nothing matches, nothing bound, or
    /// `init.lua` owns the shortcuts.
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
                "Shortcuts are managed by your init.lua."
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
