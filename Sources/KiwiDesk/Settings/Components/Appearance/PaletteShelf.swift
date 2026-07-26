import KiwiDeskCore
import SwiftUI

/// The color palette shelf (#375): the top of the Appearance
/// destination. Bundled palettes (read-only) and the user's saved
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
            L("palettes.title", "Color palette"),
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
                    chip(palette, builtin: true)
                }
            }
        }
    }

    private var userGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                groupHeader(L("palettes.mine", "My palettes"))
                Spacer()
                Button(L("palettes.import", "Import…")) {
                    importPalette()
                }
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
                .foregroundStyle(.secondary)
            }
        }
    }

    private func groupHeader(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold))
    }

    /// One palette tile: the scene thumbnail, its name, and (for a
    /// bundled palette) a muted "Built-in" caption. Clicking paints
    /// the palette. A user tile also hosts its rename popover.
    private func chip(
        _ palette: ColorPalette,
        builtin: Bool
    ) -> some View {
        Button {
            model.applyPalette(palette)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                PaletteSceneThumbnail(palette: palette)
                Text(palette.name)
                    .font(.caption)
                    .lineLimit(1)
                Text(
                    builtin
                        ? L("palettes.builtin", "Built-in") : " "
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: renameBinding(palette.name)) {
            renamePopover(palette)
        }
    }

    @ViewBuilder
    private func userMenu(_ palette: ColorPalette) -> some View {
        Button(L("palettes.rename", "Rename…")) {
            renameDraft = palette.name
            renaming = palette.name
        }
        Button(L("palettes.export", "Export…")) {
            exportPalette(palette)
        }
        Divider()
        Button(L("palettes.delete", "Delete"), role: .destructive) {
            deletePalette(palette.name)
        }
    }

    /// The trailing "+" tile that saves the current colors as a new
    /// user palette (the grid's add idiom).
    private var addTile: some View {
        Button {
            saveName = nextUserName()
            savingCurrent = true
        } label: {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [4])
                )
                .frame(height: 72)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text(
                            L(
                                "palettes.save_current",
                                "Save current colors as…"
                            )
                        )
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .padding(4)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $savingCurrent) { savePopover }
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
                .foregroundStyle(.secondary)
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
