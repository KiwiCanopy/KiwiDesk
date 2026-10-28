import KiwiDeskCore
import SwiftUI

/// Simple's Look line (#2737 ruling 3): the bundled looks as one
/// sideways line, each tile its name alone, the description its
/// hover help and VoiceOver hint. No palette editing, no saving.
struct SimpleLookCard: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SimpleCard(title: Self.title) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(model.core.bundledLooks, id: \.name) {
                        tile($0)
                    }
                }
                .padding(.vertical, 2)
            }
            CrossReferenceRow(
                prose: Self.hintProse,
                linkTitle: SettingsDestination.looks.title,
                destination: .looks
            )
        }
    }

    private func tile(_ look: ShelfLook) -> some View {
        LookTile(
            model: model,
            look: look,
            caption: nil,
            help: LookDescriptions.caption(for: look.name)
        ) {
            model.applyLook(look)
        }
        .frame(width: Self.tileWidth)
    }

    /// The way to the rest of the looks, its link at the slot.
    @MainActor static var hintProse: String {
        L(
            "simple.look.hint",
            "Want your own colors or to save a look? %1$@ in %2$@.",
            CrossReferenceRow.linkSlot,
            SettingsRootSwitch.advancedTitle
        )
    }

    /// The card's title.
    @MainActor static var title: String { L("simple.look.title", "Look") }

    /// Narrower than the shelf's grid cell: a line, not a grid.
    static let tileWidth: CGFloat = 104
}
