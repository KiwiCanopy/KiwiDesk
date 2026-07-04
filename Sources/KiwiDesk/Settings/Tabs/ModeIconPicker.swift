import AppKit
import SwiftUI

/// The mode icon chooser: a preview button that opens a popover
/// with three sources — SF Symbols, emoji, or a single text
/// character. The icon is stored as a string (a symbol name or
/// the literal character); an empty string means the default
/// menu bar glyph (05_GUI_Concept §2, Tab 5).
struct ModeIconPicker: View {
    @Binding var icon: String
    @State private var showing = false
    @State private var kind: Kind = .symbol
    @State private var search = ""

    enum Kind: String, CaseIterable, Identifiable {
        case symbol = "Symbol"
        case emoji = "Emoji"
        case text = "Text"
        var id: String { rawValue }
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 6
    )

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 6) {
                ModeIconLabel(icon: icon)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $showing) { popover }
    }

    private var popover: some View {
        VStack(spacing: 8) {
            Picker("", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            content
            Divider()
            Button("Use default icon") {
                icon = ""
                showing = false
            }
            .font(.caption)
        }
        .padding(12)
        .frame(width: 320, height: 340)
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .symbol:
            symbolGrid
        case .emoji:
            emojiGrid
        case .text:
            textEntry
        }
    }

    private var symbolGrid: some View {
        VStack(spacing: 6) {
            TextField("Search symbols", text: $search)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(filteredSymbols, id: \.self) { name in
                        gridButton {
                            Image(systemName: name)
                        } action: {
                            choose(name)
                        }
                    }
                }
            }
        }
    }

    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(ModeIcons.emoji, id: \.self) { glyph in
                    gridButton {
                        Text(glyph).font(.title3)
                    } action: {
                        choose(glyph)
                    }
                }
            }
        }
    }

    private var textEntry: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Any single character (letter, symbol, emoji).")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(
                "1 character",
                text: Binding(
                    get: { icon.count <= 1 ? icon : "" },
                    set: { icon = String($0.prefix(1)) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            .font(.title2)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filteredSymbols: [String] {
        let query = search.trimmingCharacters(
            in: .whitespaces
        )
        guard !query.isEmpty else { return ModeIcons.symbols }
        return ModeIcons.symbols.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    private func choose(_ value: String) {
        icon = value
        showing = false
    }

    private func gridButton<Label: View>(
        @ViewBuilder label: () -> Label,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            label()
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
    }
}

/// Renders the current icon: an SF Symbol if the string names
/// one, otherwise the literal character, or a placeholder when
/// empty.
struct ModeIconLabel: View {
    let icon: String

    var body: some View {
        Group {
            if icon.isEmpty {
                Label("Choose…", systemImage: "face.smiling")
            } else if isSymbol {
                Image(systemName: icon)
            } else {
                Text(icon)
            }
        }
        .frame(minWidth: 60)
    }

    private var isSymbol: Bool {
        !icon.isEmpty
            && NSImage(
                systemSymbolName: icon,
                accessibilityDescription: nil
            ) != nil
    }
}
