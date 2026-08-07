import AppKit
import KiwiDeskCore
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
    @State private var tab: IconTab = .emoji

    /// Browse tabs (#68 §6.4): emoji first — space icons are
    /// the picker's most frequent use and lean emoji. Search
    /// stays global across both vocabularies.
    enum IconTab: String, CaseIterable, Identifiable {
        case emoji = "Emoji"
        case symbols = "Symbols"
        var id: String { rawValue }

        @MainActor var title: String {
            switch self {
            case .emoji: L("icon_picker.emoji", "Emoji")
            case .symbols: L("icon_picker.symbols", "Symbols")
            }
        }

        var choices: [IconChoice] {
            switch self {
            case .emoji: IconCatalog.emoji
            case .symbols: IconCatalog.symbols
            }
        }
    }

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
                // Fixed glyph slot: every picker button is
                // the same size whether it holds an emoji, a
                // symbol, or nothing yet.
                IconGlyphLabel(icon: icon)
                    .frame(width: 20)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .neutralButtonLabel()
        // Large like the menu pickers beside it (the space
        // row's mode dropdown): the trigger is a chooser
        // button and must sit level with that family, even
        // though what it opens is a popover browser, not a
        // menu.
        .controlSize(.large)
        .help(L("icon_picker.choose.help", "Choose an icon"))
        .popover(isPresented: $showing) { popover }
    }

    // MARK: - Popover

    private var popover: some View {
        VStack(spacing: 8) {
            previewHeader
            TextField(
                L(
                    "icon_picker.search.placeholder",
                    "Search icons (or an SF Symbol name)"
                ),
                text: $search
            )
            .textFieldStyle(.roundedBorder)
            if search.trimmed.isEmpty {
                HStack(spacing: 8) {
                    SegmentedPicker(
                        selection: $tab,
                        options: IconTab.allCases.map {
                            ($0.title, $0)
                        }
                    )
                    clearButton
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if search.trimmed.isEmpty {
                        gridSection(
                            L("icon_picker.recents", "Recents"),
                            choices: recentChoices
                        )
                        gridSection(
                            nil,
                            choices: tab.choices
                        )
                    } else {
                        // Search is global: both
                        // vocabularies, emoji first, the
                        // tabs stand back.
                        specialResults
                        gridSection(
                            L("icon_picker.emoji", "Emoji"),
                            choices: filtered(
                                IconCatalog.emoji
                            )
                        )
                        gridSection(
                            L("icon_picker.symbols", "Symbols"),
                            choices: filtered(
                                IconCatalog.symbols
                            )
                        )
                    }
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
                Text(
                    L(
                        "icon_picker.preview.menu_bar",
                        "Menu bar preview"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
        case .chip:
            HStack(spacing: 8) {
                IconGlyphLabel(icon: icon)
                    .font(.caption)
                Text(
                    L(
                        "icon_picker.preview.row",
                        "Row preview"
                    )
                )
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
                            L(
                                "icon_picker.use_as_text",
                                "Use \u{201C}%1$@\u{201D} as "
                                    + "text",
                                query
                            ),
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
            .neutralButtonLabel()
            .font(.caption)
        }
    }

    /// `title` nil renders the bare grid — used for the tab
    /// grids, where the segmented control already names it.
    @ViewBuilder private func gridSection(
        _ title: String?,
        choices: [IconChoice]
    ) -> some View {
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(choices) { choice in
                        cell(choice.glyph)
                    }
                }
            }
        }
    }

    /// Clearing is a control, not a choice (§6.4): it acts on
    /// the current selection, so it sits beside the tabs
    /// instead of posing as a grid cell under Recents.
    private var clearButton: some View {
        Button {
            icon = ""
            showing = false
        } label: {
            Image(systemName: "circle.slash")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.bordered)
        .neutralButtonLabel()
        .help(
            L(
                "icon_picker.clear.help",
                "Remove icon (use the default)"
            )
        )
        .disabled(icon.isEmpty)
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
        .neutralButtonLabel()
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
