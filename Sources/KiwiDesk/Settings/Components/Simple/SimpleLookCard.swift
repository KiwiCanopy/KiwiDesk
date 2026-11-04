import AppKit
import KiwiDeskCore
import SwiftUI

/// Simple's Look line (#2737 ruling 3, re-ruled by #2943): My
/// looks newest first, then the bundled looks, as one sideways
/// line, each tile its name alone, the description its hover help
/// and VoiceOver hint, ended, while the gallery is live, by its
/// Browse tile. No palette editing, no saving. Centred while it fits
/// (owner 2026-10-29); past that a `SidewaysStrip` that follows Tab.
struct SimpleLookCard: View {
    @ObservedObject var model: SettingsModel
    @FocusState private var focusedTile: String?
    @State private var renameRequest: NameEditRequest?

    /// One thing on the line, in order.
    enum Entry: Identifiable {
        case mine(ShelfLook)
        case hairline
        case bundled(ShelfLook)
        case browse

        var id: String {
            switch self {
            case .mine(let look): "mine:" + look.name
            case .hairline: "hairline"
            case .bundled(let look): "bundled:" + look.name
            case .browse: "browse"
            }
        }

        /// The `focusedTile` value this entry takes, if any.
        var focusName: String? {
            switch self {
            case .mine(let look), .bundled(let look): look.name
            case .hairline: nil
            case .browse: browseFocus
            }
        }
    }

    var body: some View {
        let entries = Self.entries(
            mine: Self.mine(in: model),
            bundled: model.core.bundledLooks
        )
        SimpleCard(title: Self.title) {
            ViewThatFits(in: .horizontal) {
                line(entries).frame(maxWidth: .infinity)
                SidewaysStrip(
                    run: Self.run(entries: entries),
                    followed: followed(in: entries)
                ) {
                    line(entries)
                }
            }
            CrossReferenceRow(
                prose: Self.hintProse,
                linkTitle: SettingsDestination.looks.title,
                destination: .looks
            )
        }
    }

    private func line(_ entries: [Entry]) -> some View {
        HStack(alignment: .top, spacing: Self.gap) {
            ForEach(entries) { entry in
                view(for: entry).id(entry.id)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func view(for entry: Entry) -> some View {
        switch entry {
        case .mine(let look):
            tile(look)
                .popover(item: renameBinding(look.name)) {
                    renamePopover($0).settingsPopoverChrome()
                }
                .rowActions { menu(look) }
        case .hairline:
            // Sets the user's looks apart from the bundled (#2860).
            Divider()
                .frame(height: PaletteTile<EmptyView>.plateHeight)
        case .bundled(let look):
            tile(look)
        case .browse:
            browseTile
        }
    }

    /// My looks, the hairline only while one exists, the bundled
    /// looks, then Browse (#2943 ruling 2).
    static func entries(mine: [ShelfLook], bundled: [ShelfLook]) -> [Entry] {
        mine.map(Entry.mine) + (mine.isEmpty ? [] : [.hairline])
            + bundled.map(Entry.bundled) + [.browse]
    }

    static func run(entries: [Entry]) -> StripRun {
        StripRun(
            lengths: entries.map {
                if case .hairline = $0 { hairline } else { tileWidth }
            },
            gap: gap,
            depth: PaletteTile<EmptyView>.plateHeight
        )
    }

    /// The Tab-focused tile, which the strip scrolls clear of the fade.
    private func followed(in entries: [Entry]) -> StripFollow<String>? {
        guard let focusedTile,
            let index = entries.firstIndex(where: {
                $0.focusName == focusedTile
            })
        else { return nil }
        return StripFollow(id: entries[index].id, index: index)
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
        .focused($focusedTile, equals: browseFocus)
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
    static let gap: CGFloat = 10
    /// The hairline's run: `Divider`'s own width.
    static let hairline: CGFloat = 1
}

/// The Browse tile's `focusedTile` value; no look name holds it.
private let browseFocus = "\u{0}browse"
