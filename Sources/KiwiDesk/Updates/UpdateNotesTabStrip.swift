import KiwiDeskCore
import SwiftUI

/// The pinned tab strip above the notes (#1666 ruling): segments
/// at their natural width, each "Name · N", and a menu picker on
/// the same selection when they do not fit — a feed type this
/// build does not know carries a title nobody sized.
struct UpdateNotesTabStrip: View {
    let digest: UpdateNotesDigest?
    /// Whether "Next on my list" has a tab (#1849).
    var next = false
    @Binding var selection: UpdateNotesTab

    var body: some View {
        let options = Self.options(digest, next: next)
        ViewThatFits(in: .horizontal) {
            // The selected label draws bolder, so the strip is
            // judged at its widest selection: a click must not flip
            // it into the menu.
            ZStack(alignment: .leading) {
                widest(options)
                SegmentedPicker(selection: $selection, options: options)
                    .fixedSize()
                    .accessibilityLabel(Self.label)
            }
            Picker(Self.label, selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .neutralMenuLabel()
            .fixedSize()
        }
    }

    private func widest(
        _ options: [(title: String, value: UpdateNotesTab)]
    ) -> some View {
        ZStack {
            ForEach(options, id: \.value) { option in
                SegmentedPicker(
                    selection: .constant(option.value),
                    options: options
                )
                .fixedSize()
            }
        }
        .hidden()
        .accessibilityHidden(true)
    }

    @MainActor static var label: String {
        L("update.window.notes_tabs", "Release notes")
    }

    @MainActor
    static func options(
        _ digest: UpdateNotesDigest?,
        next: Bool = false
    ) -> [(title: String, value: UpdateNotesTab)] {
        UpdateNotesTabs.tabs(digest, next: next).map { tab in
            switch tab {
            case .highlights:
                return (L("update.window.highlights", "Highlights"), tab)
            case .group(let id):
                let group = digest?.group(id)
                return (group.map(UpdateNotesNaming.counted) ?? id, tab)
            case .next:
                // Short so the strip fits; the pane's heading says
                // "Next on my list" in full (#1849).
                return (L("update.window.next_tab", "Next"), tab)
            }
        }
    }
}
