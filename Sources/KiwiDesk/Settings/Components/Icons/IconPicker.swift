import AppKit
import KiwiDeskCore
import SwiftUI

/// Icon picker for mode and space icons supporting emoji and SF Symbols
/// (`IconCatalog`, #68 §6.4).
struct IconPicker: View {
    @Binding var icon: String
    /// How the popover header previews the selection.
    var preview: IconPreview = .menuBar

    @State private var showing = false
    @State private var search = ""
    @State private var tab: IconTab = .emoji

    /// Browse tabs for curated emoji and symbol collections (#68 §6.4).
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
        case menuBar
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
        .settingsActionButton()
        // Large like the menu pickers beside it (the space
        // row's mode dropdown): the trigger is a chooser
        // button and must sit level with that family, even
        // though what it opens is a popover browser, not a
        // menu.
        .controlSize(.large)
        .help(chooseHelp)
        // A glyph-only label names nothing (#812).
        .accessibilityLabel(chooseHelp)
        .popover(isPresented: $showing) { popover }
    }

    private var chooseHelp: String {
        L("icon_picker.choose.help", "Choose an icon")
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
                    // Named outside the track, as the header's
                    // mode segment is (#812).
                    .accessibilityLabel(
                        L("icon_picker.tabs_ax", "Icon source")
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

    /// Result escape hatches for plain text and raw SF Symbol names
    /// (#68 §6.4).
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
                    .settingsActionButton()
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
            .settingsActionButton()
            .font(.caption)
        }
    }

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

    /// Clear button to reset icon to default (#68 §6.4).
    private var clearButton: some View {
        Button {
            icon = ""
            showing = false
        } label: {
            Image(systemName: "circle.slash")
                .foregroundStyle(.secondary)
        }
        .settingsActionButton()
        .help(clearHelp)
        .accessibilityLabel(clearHelp)
        .disabled(icon.isEmpty)
    }

    private var clearHelp: String {
        L(
            "icon_picker.clear.help",
            "Remove icon (use the default)"
        )
    }

    private func cell(_ glyph: String) -> some View {
        Button {
            choose(glyph)
        } label: {
            IconGlyphLabel(icon: glyph)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .settingsActionButton()
        .help(glyph)
        .accessibilityLabel(glyph)
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
