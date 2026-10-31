import KiwiDeskCore
import SwiftUI

/// Look shelf (#1684): bundled and saved shelf designs, applied
/// one-shot like a palette, directly above the palette shelf.
struct LooksShelf: View {
    @ObservedObject var model: SettingsModel
    @State var saveRequest: NameEditRequest?
    @State var renameRequest: NameEditRequest?
    @State var shareRequest: NameEditRequest?
    /// The colours a look click replaced — per mount, never a
    /// stored preference, so the row offers only what this visit
    /// did (`KeepColorsOffer`).
    @State var keepColors: KeepColorsOffer?
    /// Whether the row's own tick made the latest draft write.
    @State var keepColorsWrote = false
    @FocusState var returningTile: String?
    /// Why the last save or import wrote nothing, until the next
    /// one succeeds.
    @State var failure: String?

    var store: LookStore { model.lookStore }

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 12, alignment: .top)
    ]

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.looksShelf,
            caption: L(
                "looks.caption",
                "Apply a bundled or saved look — its colors, "
                    + "where the bars sit, KiwiShelf's shape, font "
                    + "and indicators, the focus border's shape and "
                    + "sheen, and the window gaps. A one-time "
                    + "paint, not a live link; what the bars show "
                    + "is never part of a look. Its gaps move your "
                    + "windows once you save. A look you saved also "
                    + "brings its animations; a bundled one leaves "
                    + "yours as they are."
            )
        ) {
            bundledGroup
            keepColorsRow
            userGroup
            AILookPointer(model: model)
        }
        .onAppear(perform: reload)
        .onChange(of: model.isDirty) { _, dirty in
            guard !dirty else { return }
            keepColors = KeepColorsOffer.afterDraftCleaned(
                keepColors,
                tickWrote: keepColorsWrote
            )
            keepColorsWrote = false
        }
    }

    private var bundledGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(L("looks.bundled", "Bundled"))
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(model.core.bundledLooks, id: \.name) { look in
                    card(
                        look,
                        caption: LookDescriptions.caption(for: look.name)
                    )
                }
            }
        }
    }

    private var userGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                groupHeader(L("looks.mine", "My looks"))
                Spacer()
                browseButton
                Button {
                    importLook()
                } label: {
                    Label(
                        L("looks.import", "Import…"),
                        systemImage: "square.and.arrow.down"
                    )
                }
                .settingsActionButton()
                .controlSize(.small)
                shareButton
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(model.userLooks, id: \.name) { look in
                    card(
                        look,
                        caption: look.author.map(LookTile.byline),
                        captionLines: userCaptionLines
                    )
                    .focused($returningTile, equals: look.name)
                    .rowActions { userMenu(look) }
                }
                addTile
            }
            if let failure {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
            }
            if model.userLooks.isEmpty {
                Text(
                    L(
                        "looks.empty_hint",
                        "Save the current look, colors included, "
                            + "and it appears here."
                    )
                )
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
            }
        }
        .padding(.top, SettingsMetrics.shelfGroupGap)
    }

    private func groupHeader(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold))
    }

    /// My looks' one caption reservation: a byline's two lines
    /// while any look carries one, so the line ends level.
    private var userCaptionLines: Int {
        model.userLooks.contains { $0.author != nil }
            ? LookTile.captionRoom : 0
    }

    private func card(
        _ look: ShelfLook,
        caption: String?,
        captionLines: Int? = nil
    ) -> some View {
        LookTile(
            model: model,
            look: look,
            caption: caption,
            captionLines: captionLines
        ) {
            apply(look)
        }
        .popover(item: renameBinding(look.name)) { request in
            renamePopover(request)
                .settingsPopoverChrome()
        }
    }

    /// Paints `look`, its colors included, onto the draft,
    /// remembering colors no saved palette could bring back.
    func apply(_ look: ShelfLook) {
        keepColorsWrote = false
        keepColors = KeepColorsOffer.afterClicking(
            look,
            over: model.config.settings,
            prior: standingKeepColors,
            palettes: model.allPalettes
        )
        model.applyLook(look)
    }

    @ViewBuilder
    private func userMenu(_ look: ShelfLook) -> some View {
        ForEach(ColorsRowOrder.looksContextMenu, id: \.id) { key in
            menuItem(key, look)
        }
    }

    @ViewBuilder
    private func menuItem(_ key: SettingKey, _ look: ShelfLook) -> some View {
        switch key {
        case .colours(.lookRename):
            Button(L("looks.rename", "Rename…")) {
                renameRequest = NameEditRequest(
                    seed: look.name,
                    subject: look.name
                )
            }
        case .colours(.lookExport):
            Button(L("looks.export", "Export…")) { exportLook(look) }
        case .colours(.lookDelete):
            Divider()
            Button(L("looks.delete", "Delete"), role: .destructive) {
                deleteLook(look.name)
            }
        default:
            let _ = assertionFailure("unrendered look menu key: \(key.id)")
            EmptyView()
        }
    }

    /// Trailing "+" tile saving the current look.
    private var addTile: some View {
        DashedActionTile(
            systemImage: "plus",
            label: saveCurrentLabel,
            captionLines: userCaptionLines
        ) {
            saveRequest = NameEditRequest(seed: nextUserName())
        }
        .popover(item: $saveRequest) { request in
            savePopover(request)
                .settingsPopoverChrome()
        }
    }

    private var saveCurrentLabel: String {
        L("looks.save_current", "Save current look as…")
    }
}
