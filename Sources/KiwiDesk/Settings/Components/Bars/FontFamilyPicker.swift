import AppKit
import KiwiDeskCore
import SwiftUI

/// The KiwiShelf font family popover (#1681): a search field
/// focused on open that filters by substring, the two system
/// families pinned first, then every installed family A–Z, each
/// named in its own face. ↑/↓ and real pointer motion move one
/// cursor (`DropdownCursor`), Return picks it, Escape closes.
struct FontFamilyPicker: View {
    let selection: String
    let onPick: (String) -> Void
    let onClose: () -> Void

    @State private var search = ""
    @State private var cursor = DropdownCursor<String>()
    /// Where the list scrolls — set by the keyboard and the search
    /// alone, so a pointer resting on an edge row never scrolls
    /// the list out from under itself.
    @State private var scrollTarget: String?
    @FocusState private var searchFocused: Bool
    /// Read on appear, once per open (`BarFont` keeps it until the
    /// font set changes); each row builds its own face when shown.
    @State private var installed: [String] = []

    var body: some View {
        VStack(spacing: 8) {
            TextField(
                L("kiwishelf.font_family.search", "Search fonts"),
                text: $search
            )
            .textFieldStyle(.roundedBorder)
            .focused($searchFocused)
            .onKeyPress(.downArrow) { move(1) }
            .onKeyPress(.upArrow) { move(-1) }
            .onKeyPress(.return) { commit() }
            .onKeyPress(.escape) {
                onClose()
                return .handled
            }
            Divider()
            list
        }
        .padding(12)
        .frame(width: 280, height: 360)
        .onAppear {
            installed = BarFont.installedFamilies
            searchFocused = true
            cursor.opened(at: selection, pointer: DropdownPointer.live())
        }
        .onChange(of: search) { _, query in
            let next = Self.highlight(
                query: query,
                selection: selection,
                families: families
            )
            cursor.reset(to: next, pointer: DropdownPointer.live())
            scrollTarget = next
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(families, id: \.self) { family in
                        row(family)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: scrollTarget) { _, family in
                guard let family else { return }
                proxy.scrollTo(family)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }

    private func row(_ family: String) -> some View {
        let name = BarFontText.familyName(family)
        let onCursor = family == cursor.highlighted
        return Button {
            onPick(family)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .opacity(family == selection ? 1 : 0)
                FamilyName(family: family, name: name)
                Spacer(minLength: 0)
            }
            .foregroundStyle(DropdownRowStyle.ink(onCursor))
            .contentShape(Rectangle())
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .dropdownCursorRow(onCursor) {
                cursor.hover(family, pointer: DropdownPointer.live())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(family == selection ? [.isSelected] : [])
    }

    /// The rows the search shows.
    private var families: [String] {
        Self.families(installed: installed, query: search)
    }

    /// The system pair pinned first, then `installed` A–Z less the
    /// pair, filtered by substring on the name a row shows.
    static func families(installed: [String], query: String) -> [String] {
        let pinned = KiwiShelf.systemFontFamilies
        let rest = installed.filter { !pinned.contains($0) }
        return filter(pinned + rest, query: query)
    }

    /// Substring match on the name the row shows.
    static func filter(_ families: [String], query: String) -> [String] {
        let query = query.trimmed
        guard !query.isEmpty else { return families }
        return families.filter {
            BarFontText.familyName($0).searchMatches(query)
        }
    }

    /// Where the highlight sits for a search: the stored family
    /// while the search is empty, else the first match.
    static func highlight(
        query: String,
        selection: String,
        families: [String]
    ) -> String? {
        query.trimmed.isEmpty ? selection : families.first
    }

    /// A family's own face for its row, or nil for a symbol font,
    /// which cannot name itself and keeps the system face.
    static func face(of family: String) -> Font? {
        guard BarFont.drawsOwnName(family) else { return nil }
        let size = NSFont.systemFontSize
        return Font(
            BarFont.font(family: family, weight: 400, size: size)
                as CTFont
        )
    }

    private func move(_ step: Int) -> KeyPress.Result {
        guard
            let family = cursor.keyMove(
                step,
                in: families,
                pointer: DropdownPointer.live()
            )
        else { return .handled }
        scrollTarget = family
        // Focus stays in the search field, so VoiceOver hears the
        // highlight only if it is said.
        AccessibilityNotification.Announcement(
            BarFontText.familyName(family)
        ).post()
        return .handled
    }

    private func commit() -> KeyPress.Result {
        let picked = cursor.commit(
            in: families,
            pointer: DropdownPointer.live()
        )
        guard let picked else { return .ignored }
        onPick(picked)
        return .handled
    }
}

/// A family's name in its own face, built once when the row is
/// first shown — the list is lazy, so a closed popover or an
/// unscrolled tail builds nothing.
private struct FamilyName: View {
    let family: String
    let name: String
    @State private var face: Font?
    @State private var built = false

    var body: some View {
        Text(name)
            .font(face ?? .body)
            .lineLimit(1)
            .truncationMode(.middle)
            .onAppear {
                guard !built else { return }
                built = true
                face = FontFamilyPicker.face(of: family)
            }
    }
}
