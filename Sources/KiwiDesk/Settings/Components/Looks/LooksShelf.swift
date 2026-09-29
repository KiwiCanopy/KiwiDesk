import KiwiDeskCore
import SwiftUI

/// Look shelf (#1684): bundled and saved shelf designs, applied
/// one-shot like a palette, directly above the palette shelf.
struct LooksShelf: View {
    @ObservedObject var model: SettingsModel
    @State var saveRequest: NameEditRequest?
    @State var renameRequest: NameEditRequest?
    /// The colours a look click replaced — per mount, never a
    /// stored preference, so the row offers only what this visit
    /// did (`KeepColorsOffer`).
    @State var keepColors: KeepColorsOffer?
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
                    + "windows once you save."
            )
        ) {
            bundledGroup
            keepColorsRow
            userGroup
        }
        .onAppear(perform: reload)
        // A Save or a Revert ends the visit the row speaks for.
        .onChange(of: model.isDirty) { _, dirty in
            if !dirty { keepColors = nil }
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
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(model.userLooks, id: \.name) { look in
                    card(look, caption: nil)
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
    }

    private func groupHeader(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold))
    }

    /// Look tile: the picture is what a click gives — the look,
    /// its colors included — over the draft; the mark is Core's
    /// one reading (`ShelfLook.match`), and a look whose shape is
    /// live in other colors keeps it, saying so (#1752).
    private func card(_ look: ShelfLook, caption: String?) -> some View {
        let match = look.match(model.config.settings)
        let applied = match != .none
        let other = match == .otherColors
        return Button {
            apply(look)
        } label: {
            PaletteTile(
                name: look.name,
                caption: caption,
                isApplied: applied,
                note: other ? otherColorsNote : nil,
                appliedSpoken: other ? otherColorsSpoken : nil,
                captionLines: 2
            ) {
                LookPlate(settings: preview(look), spaceLabels: spaceLabels)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(applied ? [.isSelected] : [])
        .help(other ? restoreColorsHelp : "")
        .popover(item: renameBinding(look.name)) { request in
            renamePopover(request)
        }
    }

    private var otherColorsNote: String {
        L("looks.other_colors", "Other colors")
    }

    private var otherColorsSpoken: String {
        L("looks.applied_other_colors", "Applied, with other colors")
    }

    private var restoreColorsHelp: String {
        L(
            "looks.restore_colors.help",
            "Click to bring back this look's own colors."
        )
    }

    /// The draft with `look` painted on, its colors included.
    private func preview(_ look: ShelfLook) -> TilingSettings {
        var settings = model.config.settings
        look.apply(to: &settings)
        return settings
    }

    private var spaceLabels: [SpaceGlyph] {
        BarsPanelPreview.spaceLabels(of: model.config)
    }

    /// Paints `look`, its colors included, onto the draft,
    /// remembering colors no saved palette could bring back.
    func apply(_ look: ShelfLook) {
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
        Button {
            saveRequest = NameEditRequest(seed: nextUserName())
        } label: {
            PaletteTile(name: " ", dashed: true) {
                RoundedRectangle(
                    cornerRadius: PaletteSceneThumbnail.plateRadius
                )
                .fill(SettingsTheme.sunken)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "plus").font(.title2)
                        Text(saveCurrentLabel)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(4)
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saveCurrentLabel)
        .popover(item: $saveRequest) { request in
            savePopover(request)
        }
    }

    private var saveCurrentLabel: String {
        L("looks.save_current", "Save current look as…")
    }
}
