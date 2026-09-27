import KiwiDeskCore
import SwiftUI

/// The pinned tab strip above the notes (#1666 ruling): segments
/// at their natural width, named without counts, and a menu
/// picker on the same selection when they do not fit — a feed
/// type this build does not know carries a title nobody sized.
struct UpdateNotesTabStrip: View {
    let digest: UpdateNotesDigest
    @Binding var selection: UpdateNotesTab

    var body: some View {
        let options = Self.options(digest)
        ViewThatFits(in: .horizontal) {
            SegmentedPicker(selection: $selection, options: options)
                .fixedSize()
                .accessibilityLabel(Self.label)
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

    @MainActor static var label: String {
        L("update.window.notes_tabs", "Release notes")
    }

    @MainActor
    static func options(
        _ digest: UpdateNotesDigest
    ) -> [(title: String, value: UpdateNotesTab)] {
        UpdateNotesTabs.tabs(digest).map { tab in
            switch tab {
            case .highlights:
                return (L("update.window.highlights", "Highlights"), tab)
            case .group(let id):
                let group = digest.groups.first { $0.id == id }
                return (group.map(UpdateNotesNaming.name) ?? id, tab)
            }
        }
    }
}
