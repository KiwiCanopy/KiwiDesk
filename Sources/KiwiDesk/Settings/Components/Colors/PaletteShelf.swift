import KiwiDeskCore
import SwiftUI

/// The color palette shelf (#375): the top of the Colours &
/// Motion destination (#678 Phase 3 — it moved with the rest of
/// the colour story). Bundled palettes (read-only) and the user's saved
/// palettes each render as composite scene thumbnails; clicking one
/// paints its colors onto the staged config in one shot (never a
/// live link). Save-current, rename, delete, and export/import act
/// on user palettes only — the bundled set is fixed.
struct PaletteShelf: View {
    @ObservedObject var model: SettingsModel
    @State var userPalettes: [ColorPalette] = []
    @State var savingCurrent = false
    @State var saveName = ""
    @State var renaming: String?
    @State var renameDraft = ""

    var store: PaletteStore { model.paletteStore }

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
            bundledGroup
            userGroup
        }
        .onAppear(perform: reload)
    }

    private var bundledGroup: some View {
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
                        // Neon's colors read as neon on their own;
                        // it no longer force-enables the border glow
                        // (that was a sticky side-effect, #578).
                        // Instead point at the pairing without
                        // mutating state — a link that reveals the
                        // Focus-border card, where Glow lives. Hidden
                        // once glow is already on: nothing left to
                        // pair.
                        VStack(alignment: .leading, spacing: 4) {
                            chip(palette, builtin: true)
                            neonGlowLink
                        }
                    } else {
                        chip(palette, builtin: true)
                    }
                }
            }
        }
    }

    private var userGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                groupHeader(L("palettes.mine", "My palettes"))
                Spacer()
                // Explicitly sealed rather than left to the
                // default style: the two render alike, but only
                // a named style is visible to the guard that
                // keeps the accent off button labels. Left
                // implicit, this was the one button in the tree
                // still reading green after that sweep.
                // Same glyph as Shortcuts' "Import from
                // init.lua…": one verb, one symbol, wherever it
                // appears.
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
                    chip(palette, builtin: false)
                        .contextMenu { userMenu(palette) }
                }
                addTile
            }
            if userPalettes.isEmpty {
                Text(
                    L(
                        "palettes.empty_hint",
                        "Palettes you save appear here."
                    )
                )
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
            }
        }
    }

    /// Reveals the Focus-border card (where the Glow toggle lives)
    /// with the shared scroll+flash, so the Neon↔glow pairing is
    /// discoverable without the palette writing the flag itself.
    private var neonGlowLink: some View {
        Button {
            model.nav.pendingReveal = SettingsAnchor(
                // The Glow toggle moved with the ring's
                // structure — this link ships on Colours &
                // Motion and has to reach across to it.
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

    /// One palette tile: the scene thumbnail, its name, and (for a
    /// bundled palette) a muted "Built-in" caption. Clicking paints
    /// the palette. A user tile also hosts its rename popover.
    ///
    /// The applied mark is COMPUTED, never remembered (#757): a
    /// palette paints one-shot, so "last applied" would keep
    /// claiming a theme the user has since edited a colour out
    /// of. Asking whether the live colours still say what this
    /// palette says is the only answer the shelf can make that a
    /// glance at the bars cannot contradict — and it makes the
    /// mark's disappearance the honest report of a hand edit,
    /// which is why no third "modified" state exists.
    private func chip(
        _ palette: ColorPalette,
        builtin: Bool
    ) -> some View {
        let applied = palette.isApplied(to: model.config.settings)
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
        .popover(isPresented: renameBinding(palette.name)) {
            renamePopover(palette)
        }
    }

    /// The per-palette context menu, built from the census's
    /// `.palettes` show-more rows (#678 Phase 3) — the one part
    /// of this shelf that IS a uniform list, so it is the one
    /// part that renders from the census.
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
                renameDraft = palette.name
                renaming = palette.name
            }
        case .colours(.paletteExport):
            Button(L("palettes.export", "Export…")) {
                exportPalette(palette)
            }
        case .colours(.paletteDelete):
            // Last and separated: the destructive one.
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

    /// The trailing "+" tile that saves the current colors as a new
    /// user palette (the grid's add idiom).
    ///
    /// Renders through `PaletteTile` like every palette card, so
    /// it is the same height and shape and differs only in the
    /// dashed frame. It can never carry the applied mark: there
    /// is no palette here yet to be on.
    private var addTile: some View {
        Button {
            saveName = nextUserName()
            savingCurrent = true
        } label: {
            // The label stays INSIDE the plate, where it can wrap:
            // the name line is one truncating line by design (a
            // palette name has to stay on it), and "Save current
            // colors as…" does not survive that in any locale.
            // The name line still renders, blank, so the tile
            // keeps the grid's height.
            PaletteTile(name: " ", dashed: true) {
                RoundedRectangle(cornerRadius: 6)
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
        .popover(isPresented: $savingCurrent) { savePopover }
    }

    private var saveCurrentLabel: String {
        L("palettes.save_current", "Save current colors as…")
    }

    private var savePopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                L("palettes.name_placeholder", "Palette name"),
                text: $saveName
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
            .onSubmit(saveCurrent)
            if store.isBuiltinName(trimmed(saveName)) {
                Text(
                    L(
                        "palettes.reserved",
                        "That name is a built-in palette — "
                            + "choose another."
                    )
                )
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
            }
            HStack {
                Spacer()
                Button(saveLabel, action: saveCurrent)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(12)
    }

    private func renamePopover(
        _ palette: ColorPalette
    ) -> some View {
        HStack {
            TextField(
                L("palettes.name_placeholder", "Palette name"),
                text: $renameDraft
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 160)
            .onSubmit { renamePalette(from: palette.name) }
            Button(L("palettes.rename_confirm", "Rename")) {
                renamePalette(from: palette.name)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canRename(from: palette.name))
        }
        .padding(10)
    }
}
