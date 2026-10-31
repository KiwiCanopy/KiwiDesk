import AppKit
import KiwiDeskCore
import SwiftUI

/// Simple's Look line (#2737 ruling 3): the bundled looks as one
/// sideways line, each tile its name alone, the description its
/// hover help and VoiceOver hint, led by the look a gallery link
/// added (#1740) and ended, while the gallery is live, by its
/// Browse tile. No palette editing, no saving.
struct SimpleLookCard: View {
    @ObservedObject var model: SettingsModel
    @FocusState private var focusedTile: String?

    var body: some View {
        SimpleCard(title: Self.title) {
            // Centred while the line fits; scrolling once it
            // overflows (owner 2026-10-29), its trailing edge faded
            // so the line's end reads as more to come.
            ViewThatFits(in: .horizontal) {
                line.frame(maxWidth: .infinity)
                ScrollView(.horizontal, showsIndicators: false) {
                    line.padding(.trailing, Self.fade)
                }
                .mask(Self.trailingFade)
            }
            CrossReferenceRow(
                prose: Self.hintProse,
                linkTitle: SettingsDestination.looks.title,
                destination: .looks
            )
        }
    }

    private var line: some View {
        HStack(alignment: .top, spacing: 10) {
            let linked = Self.linked(in: model)?.name
            ForEach(Self.looks(in: model), id: \.name) { look in
                if look.name == linked {
                    // The gallery's look is the user's to delete; a
                    // hairline sets it apart from the bundled (#2860).
                    tile(look).rowActions { menu(look) }
                    Divider()
                        .frame(height: PaletteTile<EmptyView>.plateHeight)
                } else {
                    tile(look)
                }
            }
            browseTile
        }
        .padding(.vertical, 2)
    }

    /// The fade's length; the scrolled line ends past it, so its
    /// last tile clears the fade once scrolled to.
    private static let fade: CGFloat = 28

    private static var trailingFade: some View {
        HStack(spacing: 0) {
            Color.black
            LinearGradient(
                colors: [.black, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fade)
        }
    }

    /// The look a gallery link added, while My looks still holds it.
    static func linked(in model: SettingsModel) -> ShelfLook? {
        model.userLooks.first { $0.name == model.linkedLook }
    }

    /// The linked look, then the bundled ones.
    static func looks(in model: SettingsModel) -> [ShelfLook] {
        (linked(in: model).map { [$0] } ?? []) + model.core.bundledLooks
    }

    private func tile(_ look: ShelfLook) -> some View {
        LookTile(
            model: model,
            look: look,
            caption: nil,
            help: LookDescriptions.caption(for: look.name)
                ?? look.author.map(LookTile.byline),
            hover: { model.hoverSimple(.look(look.name), inside: $0) }
        ) {
            model.applyLook(look)
        }
        .frame(width: Self.tileWidth)
        .focused($focusedTile, equals: look.name)
    }

    /// The gallery look's menu (#2860): Delete alone; renaming and
    /// sharing are Advanced's, and a bundled look has no menu.
    private func menu(_ look: ShelfLook) -> some View {
        Button(L("looks.delete", "Delete"), role: .destructive) {
            let neighbour = DeletionFocus.neighbour(
                after: look.name,
                in: Self.looks(in: model).map(\.name)
            )
            model.deleteUserLook(look.name)
            focusedTile = neighbour
        }
    }

    /// The gallery's tile at the line's end (#1740 ▸ Browse): its
    /// site page in the browser; Simple never gets a Share door. One
    /// census row for both, named by Advanced's Browse looks…, since
    /// Simple has no search to find "More looks…" by.
    private var browseTile: some View {
        DashedActionTile(
            systemImage: "square.grid.2x2",
            label: Self.browseLabel,
            captionLines: 0
        ) {
            NSWorkspace.shared.open(SupportLinks.looks)
        }
        .frame(width: Self.tileWidth)
    }

    /// The Browse tile's label.
    @MainActor static var browseLabel: String {
        L("simple.look.browse", "More looks…")
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
