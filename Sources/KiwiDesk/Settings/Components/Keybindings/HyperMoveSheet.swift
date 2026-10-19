import KiwiDeskCore
import SwiftUI

/// One line of the Hyper move sheet, named by the host (#1870).
struct HyperMoveLine: Identifiable, Equatable {
    static let desktopID = "desktop"

    let id: String
    let name: String
    /// "⌃⌥F → ✦F", empty for the Desktop line.
    let chords: String
    /// Ticked when the sheet opens.
    let ticked: Bool
    /// Why the line cannot move; it is drawn unticked and dimmed.
    let refusal: String?
    /// Rows of the line that stay, each with its reason.
    var notes: [String] = []
}

/// One request to open the sheet via `.sheet(item:)` (#843).
struct HyperMoveRequest: Identifiable {
    let id = UUID()
    let direction: HyperShortcutMove.Direction
    /// What the lines were read from; the move applies exactly it.
    let offer: HyperShortcutMove.Offer
    let lines: [HyperMoveLine]
    let desktop: HyperMoveLine?
}

/// The Hyper move offer's sheet (#1870): the lines Core read off the
/// seed, each tickable, and one Move that stages the ticked ones into
/// the draft through `onMove`. It takes no model — the host names
/// the lines and owns the write (`SheetPresentationSeamTests`).
struct HyperMoveSheet: View {
    let request: HyperMoveRequest
    let onMove: (Set<String>, Bool) -> Void
    let onCancel: () -> Void
    @State private var picks: Set<String>
    @State private var desktop: Bool

    init(
        request: HyperMoveRequest,
        onMove: @escaping (Set<String>, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.request = request
        self.onMove = onMove
        self.onCancel = onCancel
        _picks = State(
            initialValue: Set(request.lines.filter(\.ticked).map(\.id))
        )
        _desktop = State(initialValue: request.desktop?.ticked == true)
    }

    private static let pad: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView { list }
            Divider()
            footer
        }
        .frame(width: 460)
        .frame(minHeight: 320, idealHeight: 460, maxHeight: 620)
        .background(SettingsTheme.card)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(HyperMoveWords.title(request.direction))
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            spoken(HyperMoveWords.intro(request.direction))
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.pad)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(request.lines) { line in
                row(line, isOn: binding(for: line))
            }
            if let line = request.desktop {
                Divider()
                row(line, isOn: $desktop)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.pad)
    }

    private func binding(for line: HyperMoveLine) -> Binding<Bool> {
        Binding(
            get: { picks.contains(line.id) },
            set: { on in
                if on { picks.insert(line.id) } else { picks.remove(line.id) }
            }
        )
    }

    private func row(
        _ line: HyperMoveLine,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: isOn) {
                spoken(line.name)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(.checkbox)
            .disabled(line.refusal != nil)
            Group {
                if !line.chords.isEmpty {
                    spoken(line.chords).monospaced()
                }
                ForEach(captions(of: line), id: \.self) { spoken($0) }
            }
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 20)
        }
    }

    /// `text` drawn with ✦ and announced with "Hyper" (#1870's glyph
    /// ruling), since VoiceOver has no name for the glyph.
    private func spoken(_ text: String) -> Text {
        Text(text).accessibilityLabel(HyperMoveWords.spoken(text))
    }

    private func captions(of line: HyperMoveLine) -> [String] {
        (line.refusal.map { [$0] } ?? []) + line.notes
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Only forward: the row move goes to Hyper alone (#2420).
            if request.direction == .toHyper {
                spoken(HyperMoveWords.sheetHint)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            buttons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.pad)
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button(HyperMoveWords.cancel, action: onCancel)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .settingsActionButton()
            Button(HyperMoveWords.move) { onMove(picks, desktop) }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .kiwiProminentButton()
                .disabled(picks.isEmpty && !desktop)
        }
        .frame(maxWidth: .infinity)
    }
}
