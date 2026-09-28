import KiwiDeskCore
import SwiftUI

/// Look shelf (#1684): bundled and saved shelf designs, applied
/// one-shot like a palette, directly above the palette shelf.
struct LooksShelf: View {
    @ObservedObject var model: SettingsModel
    @State var saveRequest: NameEditRequest?
    @State var renameRequest: NameEditRequest?
    @FocusState var returningTile: String?
    /// The look a click just applied and the colors it replaced —
    /// per mount, never a stored preference, so the colors row
    /// offers only what this visit did.
    @State var justApplied: AppliedLook?
    /// Why the last save or import wrote nothing, until the next
    /// one succeeds.
    @State var failure: String?

    var store: LookStore { model.lookStore }

    struct AppliedLook: Equatable {
        let look: ShelfLook
        let before: [String: String]
    }

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 12, alignment: .top)
    ]

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.looksShelf,
            caption: L(
                "looks.caption",
                "Apply a bundled or saved look to KiwiShelf — its "
                    + "shape, font and indicators, and the focus "
                    + "border's sheen. A one-time paint, not a live "
                    + "link; what the bars show is never part of a "
                    + "look."
            )
        ) {
            bundledGroup
            colorsRow
            userGroup
        }
        .onAppear(perform: reload)
    }

    private var bundledGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(L("looks.bundled", "Bundled"))
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(store.builtins(), id: \.name) { look in
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
                        "Save KiwiShelf's current look and it "
                            + "appears here."
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
    /// its colors included — over the draft; the checkmark reads
    /// the styling alone, the palette shelf marking the colors.
    private func card(_ look: ShelfLook, caption: String?) -> some View {
        let applied = look.isApplied(to: model.config.settings)
        return Button {
            apply(look)
        } label: {
            PaletteTile(name: look.name, caption: caption, isApplied: applied)
            {
                LookPlate(settings: preview(look), spaceLabels: spaceLabels)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(applied ? [.isSelected] : [])
        .popover(item: renameBinding(look.name)) { request in
            renamePopover(request)
        }
    }

    /// The draft with `look` painted on, its colors included.
    private func preview(_ look: ShelfLook) -> TilingSettings {
        var settings = model.config.settings
        look.apply(to: &settings, palette: model.palette(of: look))
        return settings
    }

    private var spaceLabels: [SpaceGlyph] {
        BarsPanelPreview.spaceLabels(of: model.config)
    }

    /// Paints `look` with its colors, remembering the colors it
    /// replaced so the row below can hand them back.
    func apply(_ look: ShelfLook) {
        let before = LookColorsOffer.before(
            clicking: justApplied.map { ($0.look, $0.before) },
            previousPalette: justApplied.flatMap {
                model.palette(of: $0.look)
            },
            settings: model.config.settings
        )
        model.applyLook(look, withColors: true)
        justApplied = AppliedLook(look: look, before: before)
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
