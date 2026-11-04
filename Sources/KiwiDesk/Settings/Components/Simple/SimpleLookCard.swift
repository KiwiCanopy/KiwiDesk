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
    @State private var scroll = StripScroll()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SimpleCard(title: Self.title) {
            ViewThatFits(in: .horizontal) {
                line.frame(maxWidth: .infinity)
                ScrollViewReader { proxy in
                    SidewaysStrip(scroll: $scroll, fades: run.fades(scroll)) {
                        line
                    }
                    .onChange(of: focusedTile) { _, id in
                        follow(id, with: proxy)
                    }
                }
            }
            CrossReferenceRow(
                prose: Self.hintProse,
                linkTitle: SettingsDestination.looks.title,
                destination: .looks
            )
        }
    }

    private var line: some View {
        HStack(alignment: .top, spacing: Self.gap) {
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

    /// The line's entries in order: each look's name, the hairline as
    /// an empty name while My looks has any, and the Browse tile.
    static func entries(mine: [String], bundled: [String]) -> [String] {
        mine + (mine.isEmpty ? [] : [""]) + bundled + [browseID]
    }

    private var entries: [String] {
        Self.entries(
            mine: Self.mine(in: model).map(\.name),
            bundled: model.core.bundledLooks.map(\.name)
        )
    }

    private var run: StripRun { Self.run(entries: entries) }

    static func run(entries: [String]) -> StripRun {
        StripRun(
            lengths: entries.map { $0.isEmpty ? hairline : tileWidth },
            gap: gap,
            depth: PaletteTile<EmptyView>.plateHeight
        )
    }

    /// Scrolls a Tab-focused tile clear of the fade.
    private func follow(_ id: String?, with proxy: ScrollViewProxy) {
        guard let id,
            let index = entries.firstIndex(of: id),
            let anchor = run.followAnchor(
                index: index,
                width: Self.tileWidth,
                scroll: scroll
            )
        else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo(id, anchor: anchor)
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
        .id(look.name)
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
        .focused($focusedTile, equals: Self.browseID)
        .id(Self.browseID)
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
    /// The Browse tile's focus and scroll id; no look name holds it.
    static let browseID = "\u{0}browse"
}
