import KiwiDeskCore
import SwiftUI

/// The "Shortcut…" picker (#3526): a pop-up over the user's Apple
/// Shortcuts, read fresh off the main actor each time it opens.
/// Picking commits, as the app picker does.
struct AppleShortcutPickerButton: View {
    let core: KiwiCore
    /// The current pick's name, or nil for none.
    let selection: String?
    let onPick: (String) -> Void
    /// Opens the list on arrival: an action picker's "Shortcut…"
    /// swaps this trigger in for itself.
    var opensOnAppear = false
    /// Every close of the list, a pick or a dismissal.
    var onClose: (() -> Void)?

    @ObservedObject private var library = AppleShortcutLibrary.shared
    @State private var showing = false
    @State private var search = ""
    @State private var loading = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: AppleShortcutAction.symbol)
                    .accessibilityHidden(true)
                Text(selection ?? Self.placeholder).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .settingsPopUpTrigger()
        .accessibilityValue(selection ?? Self.placeholder)
        .onAppear {
            if opensOnAppear {
                DispatchQueue.main.async { showing = true }
            }
        }
        .popover(isPresented: $showing) {
            popover
                .foregroundStyle(SettingsTheme.ink)
                .settingsPopoverChrome()
        }
        .onChange(of: showing) { _, open in
            if open {
                search = ""
                reload()
            } else {
                onClose?()
            }
        }
    }

    static var placeholder: String {
        L("shortcuts.apple_shortcut.choose", "Choose shortcut…")
    }

    private var shown: [String] {
        let query = search.trimmed
        let names = library.names ?? []
        guard !query.isEmpty else { return names }
        return names.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(
                L("shortcuts.apple_shortcut.search", "Search shortcuts"),
                text: $search
            )
            .textFieldStyle(.roundedBorder)
            .focused($searchFocused)
            .onSubmit {
                if let first = shown.first { pick(first) }
            }
            list
            Divider()
            Text(AppleShortcutAction.conflictBlindSpot)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 300, height: 320)
        .onAppear { searchFocused = true }
    }

    @ViewBuilder private var list: some View {
        if library.names == nil, loading {
            Text(L("shortcuts.apple_shortcut.loading", "Reading shortcuts…"))
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
                .frame(maxHeight: .infinity, alignment: .top)
        } else if shown.isEmpty {
            Text(emptyText)
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(shown, id: \.self) { name in
                        row(name)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyText: String {
        if search.trimmed.isEmpty {
            return L(
                "shortcuts.apple_shortcut.none",
                "No shortcuts yet. Make one in the Shortcuts app."
            )
        }
        return L(
            "shortcuts.apple_shortcut.no_match",
            "No shortcut matches \u{201C}%1$@\u{201D}",
            search.trimmed
        )
    }

    private func row(_ name: String) -> some View {
        let picked = name == selection
        return Button {
            pick(name)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .opacity(picked ? 1 : 0)
                    .frame(width: 12)
                    .accessibilityHidden(true)
                Text(name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .hoverHighlight(rest: .clear, edge: nil, padding: 0)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private func pick(_ name: String) {
        showing = false
        onPick(name)
    }

    private func reload() {
        loading = true
        Task {
            await library.reload(from: core)
            loading = false
        }
    }
}
