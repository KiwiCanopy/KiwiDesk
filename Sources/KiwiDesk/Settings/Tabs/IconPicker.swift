import AppKit
import SwiftUI

/// The icon chooser (#68 §6.4), one component for mode icons
/// and space icons: search-first (keywords, not just symbol
/// names), a Recents row persisted app-wide, an exact-name
/// escape hatch (any valid SF Symbol name typed into the
/// search appears as a result), single-character queries offer
/// "Use as text", and the header previews the selection at its
/// destination size. The icon stays one string — a symbol
/// name, an emoji, or a single character; empty = default.
struct IconPicker: View {
    @Binding var icon: String
    /// How the popover header previews the selection.
    var preview: IconPreview = .menuBar

    @State private var showing = false
    @State private var search = ""

    enum IconPreview {
        /// An 18 pt menu-bar mock, light and dark side by
        /// side — the glyph's job is being legible up there.
        case menuBar
        /// Row-chip size, for space icons.
        case chip
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 7
    )

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 6) {
                IconGlyphLabel(icon: icon)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $showing) { popover }
    }

    // MARK: - Popover

    private var popover: some View {
        VStack(spacing: 8) {
            previewHeader
            TextField(
                "Search icons (or an SF Symbol name)",
                text: $search
            )
            .textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    specialResults
                    if search.trimmed.isEmpty {
                        gridSection(
                            "Recents",
                            defaultCell: true,
                            choices: recentChoices
                        )
                    }
                    gridSection(
                        "Symbols",
                        choices: filtered(IconCatalog.symbols)
                    )
                    gridSection(
                        "Emoji",
                        choices: filtered(IconCatalog.emoji)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(width: 340, height: 400)
    }

    /// The selection at its destination size — for the menu
    /// bar, a light and a dark swatch side by side.
    @ViewBuilder private var previewHeader: some View {
        switch preview {
        case .menuBar:
            HStack(spacing: 8) {
                menuBarSwatch(scheme: .light)
                menuBarSwatch(scheme: .dark)
                Text("Menu bar preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        case .chip:
            HStack(spacing: 8) {
                IconGlyphLabel(icon: icon)
                    .font(.caption)
                Text("Row preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func menuBarSwatch(
        scheme: ColorScheme
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(scheme == .light ? Color.white : .black)
            .frame(width: 34, height: 26)
            .overlay {
                IconGlyphLabel(
                    icon: icon,
                    placeholder: "rectangle.3.group"
                )
                .font(.system(size: 15))
                .foregroundStyle(
                    scheme == .light ? .black : .white
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        Color.secondary.opacity(0.4)
                    )
            )
    }

    // MARK: - Result sections

    /// Escape hatches ahead of the curated grid: the query as
    /// a literal SF Symbol name, and a single character (incl.
    /// emoji) as a text icon.
    @ViewBuilder private var specialResults: some View {
        let query = search.trimmed
        if !query.isEmpty {
            HStack(spacing: 8) {
                if query.count == 1 {
                    Button {
                        choose(query)
                    } label: {
                        Label(
                            "Use \u{201C}\(query)\u{201D} "
                                + "as text",
                            systemImage: "textformat"
                        )
                    }
                }
                if isSymbolName(query),
                    !IconCatalog.symbols.contains(where: {
                        $0.glyph == query
                    })
                {
                    Button {
                        choose(query)
                    } label: {
                        Label {
                            Text(query).monospaced()
                        } icon: {
                            Image(systemName: query)
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }

    @ViewBuilder private func gridSection(
        _ title: String,
        defaultCell: Bool = false,
        choices: [IconChoice]
    ) -> some View {
        if !choices.isEmpty || defaultCell {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 6) {
                    if defaultCell {
                        noneCell
                    }
                    ForEach(choices) { choice in
                        cell(choice.glyph)
                    }
                }
            }
        }
    }

    /// Clearing is as discoverable as choosing (§6.4): the
    /// "None (default)" cell leads the Recents row.
    private var noneCell: some View {
        Button {
            icon = ""
            showing = false
        } label: {
            Image(systemName: "circle.slash")
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .help("None (default)")
    }

    private func cell(_ glyph: String) -> some View {
        Button {
            choose(glyph)
        } label: {
            IconGlyphLabel(icon: glyph)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .help(glyph)
    }

    // MARK: - Data

    private var recentChoices: [IconChoice] {
        IconCatalog.recents().map { IconChoice($0, "") }
    }

    private func filtered(
        _ choices: [IconChoice]
    ) -> [IconChoice] {
        let query = search.trimmed
        guard !query.isEmpty else { return choices }
        return choices.filter { $0.matches(query) }
    }

    private func isSymbolName(_ name: String) -> Bool {
        NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        ) != nil
    }

    private func choose(_ value: String) {
        icon = value
        IconCatalog.noteRecent(value)
        showing = false
    }
}

/// Renders an icon string: an SF Symbol if the string names
/// one, otherwise the literal character(s); a placeholder
/// symbol when empty.
struct IconGlyphLabel: View {
    let icon: String
    var placeholder: String?

    var body: some View {
        if icon.isEmpty {
            if let placeholder {
                Image(systemName: placeholder)
            } else {
                Label("Choose…", systemImage: "face.smiling")
                    .frame(minWidth: 60)
            }
        } else if isSymbol {
            Image(systemName: icon)
        } else {
            Text(icon)
        }
    }

    private var isSymbol: Bool {
        !icon.isEmpty
            && NSImage(
                systemSymbolName: icon,
                accessibilityDescription: nil
            ) != nil
    }
}
