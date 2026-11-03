import AppKit
import KiwiDeskCore
import SwiftUI

/// Simple's Look line (#2737 ruling 3, re-ruled by #2943): My
/// looks newest first, then the bundled looks, as one sideways
/// line, each tile its name alone, the description its hover help
/// and VoiceOver hint, ended, while the gallery is live, by its
/// Browse tile. No palette editing, no saving.
struct SimpleLookCard: View {
    @ObservedObject var model: SettingsModel
    @FocusState private var focusedTile: String?
    @State private var renameRequest: NameEditRequest?

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
            let mine = Self.mine(in: model)
            ForEach(mine, id: \.name) { look in
                tile(look)
                    .popover(item: renameBinding(look.name)) {
                        renamePopover($0).settingsPopoverChrome()
                    }
                    .rowActions { menu(look) }
            }
            if !mine.isEmpty {
                // A hairline sets the user's looks apart from the
                // bundled (#2860).
                Divider()
                    .frame(height: PaletteTile<EmptyView>.plateHeight)
            }
            ForEach(model.core.bundledLooks, id: \.name) { tile($0) }
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

    /// My looks, newest first: the store appends a new look and
    /// keeps a renamed or saved-over one in place (#2943).
    static func mine(in model: SettingsModel) -> [ShelfLook] {
        model.userLooks.reversed()
    }

    /// My looks, then the bundled ones.
    static func looks(in model: SettingsModel) -> [ShelfLook] {
        mine(in: model) + model.core.bundledLooks
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

    /// A user look's menu (#2860, #2943): Rename and Delete, through
    /// Advanced's writes; exporting and sharing are Advanced's, and a
    /// bundled look has no menu.
    @ViewBuilder
    private func menu(_ look: ShelfLook) -> some View {
        Button(L("looks.rename", "Rename…")) {
            renameRequest = NameEditRequest(
                seed: look.name,
                subject: look.name
            )
        }
        Divider()
        Button(L("looks.delete", "Delete"), role: .destructive) {
            let neighbour = DeletionFocus.neighbour(
                after: look.name,
                in: Self.looks(in: model).map(\.name)
            )
            model.deleteUserLook(look.name)
            focusedTile = neighbour
        }
    }

    private func renameBinding(_ name: String) -> Binding<NameEditRequest?> {
        Binding(
            get: { renameRequest?.subject == name ? renameRequest : nil },
            set: { if $0 == nil { renameRequest = nil } }
        )
    }

    private func renamePopover(_ request: NameEditRequest) -> some View {
        LooksShelf.renamePopover(request, model: model) { name, old in
            model.renameUserLook(from: old, to: name)
            renameRequest = nil
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
