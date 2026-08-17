import KiwiDeskCore
import SwiftUI

/// One request to open the preview sheet.
///
/// Presented through `.sheet(item:)` rather than `isPresented:`,
/// for the reason `NameEditRequest` already records (#843): the
/// builder is handed this value, so the content can never be built
/// from parent state written in the same tick, and a fresh `id`
/// gives each presentation its own `@State`. It matters more here
/// than for a popover — the cards live in a `LazyVGrid`, which
/// tears down the rows it scrolls past, so a presentation bound to
/// a card's own state has a lifetime the card does not control.
///
/// It carries `liveSizes` so the sheet resolves its modes against
/// the same hardware the card's glyph did. A sheet that read the
/// live displays for itself would be the second derivation
/// `PresetPreviewPlan` exists to prevent.
struct PresetPreviewRequest: Identifiable {
    let id: UUID
    let layout: StandardLayout
    let liveSizes: [CGSize]?

    init(layout: StandardLayout, liveSizes: [CGSize]?) {
        self.id = UUID()
        self.layout = layout
        self.liveSizes = liveSizes
    }
}

/// The preset preview sheet (#859): the layouts a preset actually
/// opens, drawn by the real `LayoutSchematic` family at a size
/// where they read.
///
/// **Why a sheet and not the detail panel.** The panel's object is
/// the DRAFT and this picture is of a catalog entry, and the panel
/// column is dropped by width — sound for a preview redundant with
/// the controls beside it, unsound for a fact stated nowhere else.
/// `.profiles` is deliberately absent from
/// `SettingsDetailPanelOffer.offering` and `DetailPanelTests` pins
/// the refusal with all three grounds; the ruling is argued in
/// `docs/design-decisions.md`.
///
/// **Drawn from the preset's own `TilingSettings`, never the
/// draft.** That one line is what keeps Profiles a CATALOG surface
/// rather than a draft-preview one, and drawing it from
/// `model.config.settings` would flip the panel refusal above
/// without anything noticing. `PresetPreviewSettingsTests` is what
/// notices.
///
/// **`.tile` at its own size, never a third `SchematicScale`.** A
/// factor over `.tile` is the settled expression for a smaller
/// mount (`HomeCardSchematicBand` at 70/84, the tour at 46/84);
/// this sheet is the case that needs no factor at all, which is
/// precisely #859's argument — a 200 pt card cannot hold a legible
/// schematic and a sheet can. Captions stay suppressed at `.tile`
/// by #753's ruling, so the mode's name is the tile's own label.
struct PresetPreviewSheet: View {
    let layout: StandardLayout
    /// The live screens, or nil where the sheet opened from the
    /// "For other setups" drawer — threaded through to the plan
    /// unchanged, never re-derived here.
    let liveSizes: [CGSize]?
    let onDone: () -> Void

    /// `.tile`'s fixed width, so the grid's column derives from
    /// the schematic it mounts rather than restating a number.
    ///
    /// The `132` is unreachable: `SchematicScale.width` answers
    /// non-nil for `.tile` by construction and nil only for
    /// `.panel`, which this sheet does not mount.
    /// `PresetPreviewSheetTests` asserts the two are equal, so the
    /// fallback cannot start standing in for a moved constant.
    static let tileWidth = SchematicScale.tile.width ?? 132

    private var plan: PresetPreviewPlan {
        PresetPreviewPlan(layout: layout, liveSizes: liveSizes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView { screenGroups }
            Divider()
            footer
        }
        // The sheet states its own size. It compares no window
        // width, so it adds no second derivation beside
        // `SettingsWidthClass`, and the ruled narrowing order
        // does not reach it: a sheet is not the settings form.
        .frame(
            minWidth: 520,
            idealWidth: 640,
            minHeight: 380,
            idealHeight: 520
        )
        .background(SettingsTheme.card)
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(layout.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                if layout.isStandard {
                    BadgeChip(label: standardBadge)
                }
            }
            Text(layout.displaySummary)
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    /// The same key the card's badge is authored with — one badge,
    /// one noun. Two call sites of one key with identical English
    /// is what `extract-keys` allows; only differing English at
    /// two sites is drift, and it fails loudly on that.
    private var standardBadge: String {
        L("presets.standard_badge", "standard")
    }

    private var screenGroups: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(plan.groups) { group in
                screenGroup(group)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    /// One screen's heading over its spaces.
    ///
    /// The heading is the SCREEN and the label under each tile is
    /// its mode, rather than a "screen · mode" pair per tile: on a
    /// one-screen preset — which is three of the seven, and the
    /// ones most likely to be opened — a per-tile pair repeats the
    /// same two words on every row of the grid, and Command Center
    /// would repeat them ten times over three screens.
    private func screenGroup(
        _ group: PresetPreviewPlan.Group
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // `.secondary` matches the sibling sub-group heading
            // `PresetsSection.otherCountGroup` already draws, and
            // no ancestor here sets a foreground for it to derive
            // the wrong colour from.
            Text(presetScreenName(group.screen))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: tileColumns,
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(group.slots) { tile($0) }
            }
        }
    }

    private var tileColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: Self.tileWidth),
                spacing: 12,
                alignment: .topLeading
            )
        ]
    }

    /// One space: its schematic, then the layout's name under it —
    /// the pairing `LayoutStrip` already draws, so a mode named
    /// beside a schematic reads the same in both places.
    ///
    /// Nothing here overrides accessibility. `SchematicCanvas`
    /// gives the drawing its own label, and naming this stack
    /// would REPLACE that label with a bare mode name — the
    /// failure `AppRulesCensusRenderTests` records for menus, in a
    /// different costume.
    private func tile(
        _ slot: PresetPreviewPlan.Slot
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LayoutSchematicView(
                mode: slot.mode,
                settings: layout.settings,
                windows: LayoutSchematic.defaultWindowCount,
                scale: .tile
            )
            Label(
                slot.mode.displayName,
                systemImage: slot.mode.glyph
            )
            .font(.caption)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(SettingsTheme.ink2)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(doneLabel, action: onDone)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .kiwiProminentButton()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
    }

    private var doneLabel: String {
        L("presets.preview.done", "Done")
    }
}
