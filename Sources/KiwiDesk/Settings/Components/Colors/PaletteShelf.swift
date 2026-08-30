import KiwiDeskCore
import SwiftUI

/// Color palette shelf (#375, #678).
struct PaletteShelf: View {
    @ObservedObject var model: SettingsModel
    @State var userPalettes: [ColorPalette] = []
    /// Presentations for save and rename popovers (#843).
    @State var saveRequest: NameEditRequest?
    @State var renameRequest: NameEditRequest?
    /// Focus target after tile deletion (#816).
    @FocusState var returningTile: String?

    var store: PaletteStore { model.paletteStore }

    /// Staged config colors extracted once per redraw (#843).
    private var liveColors: [String: String] {
        ColorPaletteKeys.extract(from: model.config.settings)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 12)
    ]

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.paletteShelf,
            caption: L(
                "palettes.caption",
                "Apply a bundled or saved set of colors to the "
                    + "App Bar, Space Bar, borders, and drag "
                    + "visuals — a one-time paint, not a live link."
            )
        ) {
            let live = liveColors
            bundledGroup(live)
            userGroup(live)
        }
        .onAppear(perform: reload)
    }

    private func bundledGroup(
        _ live: [String: String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(L("palettes.bundled", "Bundled"))
            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(store.builtins(), id: \.name) { palette in
                    if palette.name == PaletteCatalog.neonName
                        && !model.config.settings.borderStyle.glow
                    {
                        // Links to Glow setting without mutating state (#578).
                        VStack(alignment: .leading, spacing: 4) {
                            chip(palette, builtin: true, live: live)
                            neonGlowLink
                        }
                    } else {
                        chip(palette, builtin: true, live: live)
                    }
                }
            }
        }
    }

    private func userGroup(
        _ live: [String: String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                groupHeader(L("palettes.mine", "My palettes"))
                Spacer()
                Button {
                    importPalette()
                } label: {
                    Label(
                        L("palettes.import", "Import…"),
                        systemImage: "square.and.arrow.down"
                    )
                }
                .settingsActionButton()
                .controlSize(.small)
            }
            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(userPalettes, id: \.name) { palette in
                    chip(palette, builtin: false, live: live)
                        .focused($returningTile, equals: palette.name)
                        // Context actions on the tile (#678, #816, #845).
                        .rowActions { userMenu(palette) }
                }
                addTile
            }
            if userPalettes.isEmpty {
                // Explains what user palettes are for (#678).
                Text(
                    L(
                        "palettes.empty_hint",
                        "The palettes above paint KiwiDesk in one "
                            + "click. Save colors of your own and "
                            + "they appear here."
                    )
                )
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
            }
        }
    }

    /// Reveals the Focus-border card where Glow lives.
    private var neonGlowLink: some View {
        Button {
            model.nav.pendingReveal = SettingsAnchor(
                destination: .gapsAndBorders,
                anchor: SettingsCatalog.gapsAndBorders
                    .focusBorder.id
            )
        } label: {
            Text(L("palettes.neon_glow_hint", "Pair with Glow"))
                .font(.caption2)
        }
        .buttonStyle(.link)
        .controlSize(.small)
    }

    private func groupHeader(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold))
    }

    /// Palette tile; applied state is computed live (#757).
    private func chip(
        _ palette: ColorPalette,
        builtin: Bool,
        live: [String: String]
    ) -> some View {
        let applied = palette.isApplied(matching: live)
        return Button {
            model.applyPalette(palette)
        } label: {
            PaletteTile(
                name: palette.name,
                caption: builtin
                    ? L("palettes.builtin", "Built-in") : nil,
                isApplied: applied
            ) {
                PaletteSceneThumbnail(palette: palette)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(applied ? [.isSelected] : [])
        .popover(item: renameBinding(palette.name)) { request in
            renamePopover(request)
        }
    }

    /// Per-palette context menu (#678).
    @ViewBuilder
    private func userMenu(_ palette: ColorPalette) -> some View {
        ForEach(
            ColorsRowOrder.palettesContextMenu,
            id: \.id
        ) { key in
            menuItem(key, palette)
        }
    }

    @ViewBuilder
    private func menuItem(
        _ key: SettingKey,
        _ palette: ColorPalette
    ) -> some View {
        switch key {
        case .colours(.paletteRename):
            Button(L("palettes.rename", "Rename…")) {
                renameRequest = NameEditRequest(
                    seed: palette.name,
                    subject: palette.name
                )
            }
        case .colours(.paletteExport):
            Button(L("palettes.export", "Export…")) {
                exportPalette(palette)
            }
        case .colours(.paletteDelete):
            Divider()
            Button(
                L("palettes.delete", "Delete"),
                role: .destructive
            ) {
                deletePalette(palette.name)
            }
        default:
            let _ = assertionFailure(
                "unrendered palette menu key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// Trailing "+" tile saving current colors as a user palette.
    private var addTile: some View {
        Button {
            saveRequest = NameEditRequest(seed: nextUserName())
        } label: {
            // The label stays INSIDE the plate, where it can wrap:
            // the name line is one truncating line by design (a
            // palette name has to stay on it), and "Save current
            // colors as…" does not survive that in any locale.
            // The name line still renders, blank, so the tile
            // keeps the grid's height.
            PaletteTile(name: " ", dashed: true) {
                RoundedRectangle(
                    cornerRadius: PaletteSceneThumbnail.plateRadius
                )
                .fill(SettingsTheme.sunken)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title2)
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
        L("palettes.save_current", "Save current colors as…")
    }
}
